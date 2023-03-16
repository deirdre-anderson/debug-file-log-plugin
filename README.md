# debug-file-log-plugin

A modified file-log plugin that can be enabled along side an existing logging plugin to write request and response bodies to a local file for debugging purposes without impact to existing logging and monitoring configuration. 

See the file-log plugin documenation for details on how to configure this plugin - https://docs.konghq.com/hub/kong-inc/file-log/

Note: The client body buffer will have to be large enough to accomodate the incoming request body in order for the plugin to log the payload. If you see the following warning in your error.log "a client request body is buffered to a temporary file" and/or do not see your request body being logged validate that this property is set and is large enough.

```
nginx_http_client_body_buffer_size
```

See this Knowledge Base article for more details : https://support.konghq.com/support/s/article/Kong-plugin-produces-a-warning-a-client-request-body-is-buffered-to-a-temporary-file 