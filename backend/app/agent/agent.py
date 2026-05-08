import json
import logging
import os
from dataclasses import dataclass, field

from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_google_genai import ChatGoogleGenerativeAI

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
        self._llm = self._create_llm()
        self._agent_executor = self._build_agent()

    def _create_llm(self):
        """Create the LLM instance based on the configured provider."""
        provider = settings.LLM_PROVIDER.lower()

        if provider == "anthropic":
            if not settings.ANTHROPIC_API_KEY:
                raise ValueError("ANTHROPIC_API_KEY is required for Anthropic provider")
            return ChatAnthropic(
                model=self._model_name,
                anthropic_api_key=settings.ANTHROPIC_API_KEY,
                temperature=settings.LLM_TEMPERATURE,
                max_tokens=settings.LLM_MAX_TOKENS,
            )
        elif provider == "google":
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
        elif provider == "ollama":
            from langchain_ollama import ChatOllama

            ollama_base = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
            return ChatOllama(
                model=self._model_name,
                base_url=ollama_base,
                temperature=settings.LLM_TEMPERATURE,
                num_ctx=4096,
            )
        else:
            raise ValueError(
                f"Unsupported LLM provider: {provider}. Use 'anthropic', 'google', or 'ollama'."
            )

    def _build_agent(self) -> AgentExecutor:
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
            llm=self._llm,
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

            return AgentResponse(output=output, tools_used=tools_used)

        except Exception as exc:
            logger.exception("Agent execution failed")
            return AgentResponse(
                output="Xin lỗi, tôi gặp lỗi khi xử lý yêu cầu. Vui lòng thử lại.",
                tools_used=[],
            )

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
