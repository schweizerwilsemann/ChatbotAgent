import json
import logging
import os
import re
from dataclasses import dataclass, field

from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_google_genai import ChatGoogleGenerativeAI

from app.agent.intent_router import IntentRouter
from app.agent.prompts import SYSTEM_PROMPT
from app.core.config import settings
from app.core.neo4j_client import Neo4jClient

logger = logging.getLogger(__name__)


@dataclass
class AgentResponse:
    output: str
    tools_used: list[str] = field(default_factory=list)


class VenueAgent:
    def __init__(
        self,
        model_name: str | None = None,
        tools: list | None = None,
        neo4j_client: Neo4jClient | None = None,
    ) -> None:
        self._model_name = model_name or settings.LLM_MODEL
        self._tools = tools or []
        self._neo4j_client = neo4j_client
        self._intent_router = IntentRouter()
        self._llm = self._create_llm()
        self._agent_executor = self._build_agent(self._llm)
        self._fallback_agent_executor = None
        self._fallback_provider = None
        logger.info(
            "LLM config — provider: %s | model: %s | MiMo key: %s",
            settings.LLM_PROVIDER,
            self._model_name,
            "set" if settings.MIMO_API_KEY else "EMPTY",
        )
        if settings.LLM_PROVIDER.lower() != "mimo":
            # Primary fallback: MiMo API (external, no local model needed)
            if settings.MIMO_API_KEY:
                try:
                    fallback_llm = self._create_mimo_llm(settings.MIMO_MODEL)
                    self._fallback_agent_executor = self._build_agent(fallback_llm)
                    self._fallback_provider = "mimo"
                    logger.info(
                        "Fallback LLM configured: MiMo (%s)", settings.MIMO_MODEL
                    )
                except Exception:
                    logger.warning("Could not initialize MiMo fallback", exc_info=True)
            else:
                logger.info("MiMo API key not set, skipping MiMo fallback")
            # Secondary fallback: Ollama (local model)
            if not self._fallback_agent_executor:
                try:
                    fallback_llm = self._create_ollama_llm(
                        settings.OLLAMA_FALLBACK_MODEL
                    )
                    self._fallback_agent_executor = self._build_agent(fallback_llm)
                    self._fallback_provider = "ollama"
                    logger.info(
                        "Fallback LLM configured: Ollama (%s)",
                        settings.OLLAMA_FALLBACK_MODEL,
                    )
                except Exception:
                    logger.warning(
                        "Could not initialize Ollama fallback", exc_info=True
                    )
        if not self._fallback_agent_executor:
            logger.warning("No fallback LLM configured — rate limits will cause errors")

    def _create_llm(self):
        """Create the LLM instance based on the configured provider."""
        provider = settings.LLM_PROVIDER.lower()

        if provider == "google":
            api_key = settings.GEMINI_API_KEY or settings.GOOGLE_API_KEY
            if not api_key:
                raise ValueError(
                    "GEMINI_API_KEY or GOOGLE_API_KEY is required for Google provider"
                )
            return ChatGoogleGenerativeAI(
                model=self._model_name,
                google_api_key=api_key,
                temperature=settings.LLM_TEMPERATURE,
                max_output_tokens=settings.LLM_MAX_TOKENS,
            )
        elif provider == "mimo":
            return self._create_mimo_llm(self._model_name)
        elif provider == "ollama":
            return self._create_ollama_llm(self._model_name)
        else:
            raise ValueError(
                f"Unsupported LLM provider: {provider}. Use 'google', 'mimo', or 'ollama'."
            )

    @staticmethod
    def _create_mimo_llm(model_name: str):
        """Create MiMo LLM instance using OpenAI-compatible API."""
        from langchain_openai import ChatOpenAI

        api_key = settings.MIMO_API_KEY
        if not api_key:
            raise ValueError("MIMO_API_KEY is required for MiMo provider")

        return ChatOpenAI(
            model=model_name or settings.MIMO_MODEL,
            openai_api_key=api_key,
            openai_api_base=settings.MIMO_API_BASE_URL,
            temperature=settings.LLM_TEMPERATURE,
            max_tokens=settings.LLM_MAX_TOKENS,
        )

    @staticmethod
    def _create_ollama_llm(model_name: str):
        from langchain_ollama import ChatOllama

        ollama_base = os.environ.get("OLLAMA_BASE_URL", settings.OLLAMA_BASE_URL)
        return ChatOllama(
            model=model_name,
            base_url=ollama_base,
            temperature=settings.LLM_TEMPERATURE,
            num_ctx=4096,
        )

    def _build_agent(self, llm) -> AgentExecutor:
        """Build the LangChain agent executor with tools."""
        prompt = ChatPromptTemplate.from_messages(
            [
                ("system", SYSTEM_PROMPT),
                MessagesPlaceholder(variable_name="chat_history", optional=True),
                ("human", "{input}"),
                MessagesPlaceholder(variable_name="agent_scratchpad"),
            ]
        )

        agent = create_tool_calling_agent(
            llm=llm,
            tools=self._tools,
            prompt=prompt,
        )

        return AgentExecutor(
            agent=agent,
            tools=self._tools,
            verbose=settings.DEBUG,
            max_iterations=5,
            handle_parsing_errors=True,
            return_intermediate_steps=True,
        )

    async def process(self, message: str, session_history: list[dict]) -> AgentResponse:
        """Process a user message through the AI agent."""
        routed = self._intent_router.route(message)
        if routed:
            return AgentResponse(output=routed.answer, tools_used=[])

        chat_history = self._convert_history(
            session_history[:-1] if session_history else []
        )

        try:
            result = await self._agent_executor.ainvoke(
                {
                    "input": message,
                    "chat_history": chat_history,
                }
            )

            output = result.get("output", "")
            tools_used = self._extract_tools_used(result)
            repaired = await self._repair_tool_leak(output)
            if repaired:
                return repaired
            return AgentResponse(output=output, tools_used=tools_used)

        except Exception as exc:
            if self._should_fallback_to_ollama(exc) and self._fallback_agent_executor:
                logger.warning(
                    "%s rate limit hit, falling back to %s",
                    settings.LLM_PROVIDER,
                    self._fallback_provider,
                )
                try:
                    result = await self._fallback_agent_executor.ainvoke(
                        {
                            "input": message,
                            "chat_history": chat_history,
                        }
                    )
                    output = result.get("output", "")
                    tools_used = self._extract_tools_used(result)
                    repaired = await self._repair_tool_leak(output)
                    if repaired:
                        return repaired
                    return AgentResponse(output=output, tools_used=tools_used)
                except Exception:
                    logger.exception(
                        "%s fallback execution failed", self._fallback_provider
                    )

            logger.exception("Agent execution failed")
            return AgentResponse(
                output="Xin lỗi, tôi gặp lỗi khi xử lý yêu cầu. Vui lòng thử lại.",
                tools_used=[],
            )

    @staticmethod
    def _should_fallback_to_ollama(exc: Exception) -> bool:
        text = str(exc).lower()
        return (
            "429" in text
            or "resource_exhausted" in text
            or "quota" in text
            or "rate limit" in text
            or "rate_limit" in text
        )

    async def _repair_tool_leak(self, output: str) -> AgentResponse | None:
        """Recover when an LLM prints a tool call instead of executing it."""
        normalized = output.strip()
        lowered = normalized.lower()
        if not (
            '"name"' in lowered
            and "arguments" in lowered
            and any(getattr(tool, "name", "") in normalized for tool in self._tools)
        ):
            return None

        logger.warning("Detected leaked tool call in model output: %s", normalized)

        if "query_knowledge" in normalized:
            question = self._extract_argument(normalized, "question")
            if question:
                for tool in self._tools:
                    if getattr(tool, "name", "") == "query_knowledge":
                        result = await tool.ainvoke({"question": question})
                        return AgentResponse(
                            output=str(result), tools_used=["query_knowledge"]
                        )

            return AgentResponse(
                output=(
                    "Mình có thể hỗ trợ kiến thức kỹ thuật và luật chơi cho "
                    "bida, pickleball và cầu lông."
                ),
                tools_used=[],
            )

        return AgentResponse(
            output="Mình cần thêm một chút thông tin để xử lý yêu cầu này.",
            tools_used=[],
        )

    @staticmethod
    def _extract_argument(output: str, argument_name: str) -> str | None:
        match = re.search(
            rf'"{re.escape(argument_name)}"\s*:\s*"([^"]+)"',
            output,
        )
        return match.group(1) if match else None

    @staticmethod
    def _convert_history(history: list[dict]) -> list:
        """Convert session history dicts to LangChain message objects."""
        messages = []
        for msg in history:
            role = msg.get("role", "")
            content = msg.get("content", "")
            if role == "user":
                messages.append(HumanMessage(content=content))
            elif role == "assistant":
                messages.append(AIMessage(content=content))
        return messages

    @staticmethod
    def _extract_tools_used(result: dict) -> list[str]:
        """Extract tool names from intermediate steps."""
        tools_used = []
        for step in result.get("intermediate_steps", []):
            if step and len(step) >= 2:
                action = step[0]
                tool_name = getattr(action, "tool", None)
                if tool_name and tool_name not in tools_used:
                    tools_used.append(tool_name)
        return tools_used
