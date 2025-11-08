## Connecting via MCP
The Crawl4AI server exposes two MCP endpoints:

Server-Sent Events (SSE): http://localhost:11235/mcp/sse
WebSocket: ws://localhost:11235/mcp/ws
Using with Claude Code
You can add Crawl4AI as an MCP tool provider in Claude Code with a simple command:

### Add the Crawl4AI server as an MCP provider
claude mcp add --transport sse c4ai-sse http://localhost:11235/mcp/sse

### List all MCP providers to verify it was added
claude mcp list
Copy
Once connected, Claude Code can directly use Crawl4AI's capabilities like screenshot capture, PDF generation, and HTML processing without having to make separate API calls.

## Available MCP Tools
When connected via MCP, the following tools are available:

md - Generate markdown from web content
html - Extract preprocessed HTML
screenshot - Capture webpage screenshots
pdf - Generate PDF documents
execute_js - Run JavaScript on web pages
crawl - Perform multi-URL crawling
ask - Query the Crawl4AI library context
Testing MCP Connections
You can test the MCP WebSocket connection using the test file included in the repository:

### From the repository root
python tests/mcp/test_mcp_socket.py
Copy
MCP Schemas
Access the MCP tool schemas at http://localhost:11235/mcp/schema for detailed information on each tool's parameters and capabilities.

