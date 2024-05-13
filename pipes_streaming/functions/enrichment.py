import base64
import json


def handler(events, context):
    enriched_events = []
    for event in events:
        event["enrichment"] = "Hello from Lambda"
        enriched_events.append(event)
        # Trigger intentional failure
        data = base64.b64decode(event["data"]).decode("utf-8")
        data_json = json.loads(data)
        if data_json.get("fail", False):
            raise Exception("Fail intentionally")
    return enriched_events
