import json

with open("eval/results_retrieval.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print("=== QUERY MISS (RR=0) ===")
for d in data["details"]:
    if d["mrr"] == 0:
        print(f"  [{d['id']}] {d['query']}")
        print(f"    Expected: {d['expected']}")
        print(f"    Retrieved: {d['retrieved'][:3]}")
        print()

print("=== QUERY HIT (RR>0) ===")
for d in data["details"]:
    if d["mrr"] > 0:
        matched = d.get("matched", [])
        print(f"  [{d['id']}] {d['query']}  RR={d['mrr']:.2f}")
        print(f"    Expected: {d['expected']}")
        print(f"    Matched:  {matched}")
        print()
