var clusters = [
    {
      NAME: "rest-proxy-1",
      KAFKA_REST: "http://localhost:8885",
      MAX_BYTES: "50000",
      RECORD_POLL_TIMEOUT: "5000",
      DEBUG_LOGS_ENABLED: true,
      LAZY_LOAD_TOPIC_META: false
    },
    {
      NAME: "rest-proxy-2",
      KAFKA_REST: "http://localhost:8886",
      MAX_BYTES: "50000",
      COLOR: "blue", // Optional
      RECORD_POLL_TIMEOUT: "5000",
      DEBUG_LOGS_ENABLED: true,
      LAZY_LOAD_TOPIC_META: false
    }
  ];