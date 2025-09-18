import Foundation

struct TidySchema {
    static let jsonSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "project": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "locale": [
                        "type": "object",
                        "properties": [
                            "lang": ["type": "string"],
                            "region": ["type": "string"]
                        ],
                        "required": ["lang", "region"]
                    ]
                ],
                "required": ["title", "locale"]
            ],
            "tasks": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Clear task description"
                        ],
                        "priority": [
                            "anyOf": [
                                [
                                    "type": "string",
                                    "enum": ["low", "normal", "high"]
                                ],
                                ["type": "null"]
                            ],
                            "description": "Task urgency"
                        ],
                        "due": [
                            "anyOf": [
                                ["type": "string"],
                                ["type": "null"]
                            ],
                            "description": "Due date in YYYY-MM-DD"
                        ],
                        "rationale": [
                            "anyOf": [
                                ["type": "string"],
                                ["type": "null"]
                            ],
                            "description": "Reasoning for the task"
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ],
        "required": ["project", "tasks"]
    ]
}
