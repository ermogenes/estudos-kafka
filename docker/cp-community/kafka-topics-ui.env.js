var clusters = [
  {
    NAME: "restproxy1",
    KAFKA_REST: "http://localhost:48082",
    MAX_BYTES: "50000",
    RECORD_POLL_TIMEOUT: "5000",
    DEBUG_LOGS_ENABLED: true,
    LAZY_LOAD_TOPIC_META: false
  },
  {
    NAME: "restproxy2",
    KAFKA_REST: "http://localhost:48182",
    MAX_BYTES: "50000",
    COLOR: "blue", // Optional
    RECORD_POLL_TIMEOUT: "5000",
    DEBUG_LOGS_ENABLED: true,
    LAZY_LOAD_TOPIC_META: false
  }
]
