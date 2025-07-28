# Design Document

## Overview

This design document outlines the completion of the DHT (Distributed Hash Table) protocol and Bootstrap system enhancement for the Eastsea blockchain project. The implementation will focus on four critical message handlers in the DHT system and peer discovery logic in the Bootstrap system, along with network interface improvements.

The design builds upon the existing P2P infrastructure and integrates with the current routing table, message serialization, and peer management systems. The goal is to achieve full P2P networking functionality that enables reliable peer discovery, routing, and network resilience.

## Architecture

### DHT Protocol Architecture

The DHT system follows the Kademlia protocol design with the following key components:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DHT Node      │    │  Routing Table  │    │ Message Handler │
│                 │    │                 │    │                 │
│ - Node ID       │◄──►│ - K-buckets     │◄──►│ - ping/pong     │
│ - Local Info    │    │ - Node entries  │    │ - find_node     │
│ - Peer Mgmt     │    │ - Distance calc │    │ - responses     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │    P2P Network Layer    │
                    │                         │
                    │ - Message Serialization │
                    │ - TCP Communication     │
                    │ - Peer Connections      │
                    └─────────────────────────┘
```

### Bootstrap System Architecture

The Bootstrap system provides network entry points and peer discovery:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Bootstrap Client│    │ Peer Discovery  │    │ Connection Mgmt │
│                 │    │                 │    │                 │
│ - Server List   │◄──►│ - Peer Parsing  │◄──►│ - Auto Connect  │
│ - Request Logic │    │ - Validation    │    │ - Retry Logic   │
│ - Fallback      │    │ - Filtering     │    │ - Health Check  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │   Network Interface     │
                    │                         │
                    │ - IP Detection          │
                    │ - Interface Monitoring  │
                    │ - IPv4/IPv6 Support     │
                    └─────────────────────────┘
```

## Components and Interfaces

### DHT Message Handlers

#### 1. handlePing Implementation
```zig
fn handleDHTPing(dht: *DHT, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    // Parse incoming ping message
    // Validate sender information
    // Create pong response with node info
    // Update routing table with sender
    // Send pong response
}
```

**Key Responsibilities:**
- Validate ping message format and authenticity
- Extract sender node information (ID, address, port)
- Update local routing table with sender information
- Generate proper pong response with local node info
- Handle message serialization errors gracefully

#### 2. handlePong Implementation
```zig
fn handleDHTPong(dht: *DHT, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    // Parse pong response
    // Validate response matches pending request
    // Update routing table with confirmed node
    // Remove from pending requests
    // Trigger any waiting operations
}
```

**Key Responsibilities:**
- Match pong responses to pending ping requests
- Validate response authenticity and timing
- Update routing table with confirmed active nodes
- Clean up pending request tracking
- Maintain node liveness information

#### 3. handleFindNode Implementation
```zig
fn handleDHTFindNode(dht: *DHT, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    // Parse find_node request
    // Validate target node ID
    // Query routing table for K closest nodes
    // Serialize node list response
    // Send find_node_response
}
```

**Key Responsibilities:**
- Parse and validate target node ID from request
- Query routing table for K closest nodes to target
- Format node information (ID, address, port) for response
- Handle cases where fewer than K nodes are available
- Maintain proper Kademlia distance calculations

#### 4. handleFindNodeResponse Implementation
```zig
fn handleDHTFindNodeResponse(dht: *DHT, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    // Parse node list from response
    // Validate node information
    // Update routing table with new nodes
    // Trigger connections to promising nodes
    // Continue iterative lookup if needed
}
```

**Key Responsibilities:**
- Parse list of nodes from find_node response
- Validate each node's contact information
- Update routing table with new node entries
- Prioritize nodes based on distance to lookup target
- Support iterative lookup continuation

### Bootstrap System Enhancement

#### Peer Discovery Logic
```zig
fn processPeerList(bootstrap: *Bootstrap, peer_list: []const u8) !void {
    // Parse peer list (JSON or comma-separated)
    // Validate peer addresses and ports
    // Filter out already known peers
    // Attempt connections to new peers
    // Update peer database
}
```

**Key Features:**
- Support multiple peer list formats (JSON, CSV)
- Validate IP addresses and port ranges
- Implement connection retry with exponential backoff
- Maintain peer quality metrics
- Handle connection failures gracefully

#### Network Interface Detection
```zig
fn detectNetworkInterfaces(allocator: std.mem.Allocator) ![]NetworkInterface {
    // Enumerate available network interfaces
    // Detect IPv4 and IPv6 addresses
    // Identify default routes
    // Filter out loopback and inactive interfaces
    // Return prioritized interface list
}
```

**Key Features:**
- Cross-platform interface enumeration
- IPv4/IPv6 dual-stack support
- Dynamic interface change detection
- Interface priority ranking
- Fallback to system commands when needed

## Data Models

### DHT Node Information
```zig
const DHTNode = struct {
    id: [20]u8,           // 160-bit node ID
    address: []const u8,  // IP address string
    port: u16,            // UDP/TCP port
    last_seen: i64,       // Unix timestamp
    distance: u160,       // XOR distance from local node
    status: NodeStatus,   // Active, Questionable, Bad
};

const NodeStatus = enum {
    Active,      // Recently responded
    Questionable, // No recent response
    Bad,         // Failed multiple times
};
```

### Bootstrap Peer Entry
```zig
const BootstrapPeer = struct {
    address: []const u8,
    port: u16,
    last_attempt: i64,
    success_count: u32,
    failure_count: u32,
    status: PeerStatus,
};

const PeerStatus = enum {
    Unknown,
    Connecting,
    Connected,
    Failed,
    Blacklisted,
};
```

### Network Interface Information
```zig
const NetworkInterface = struct {
    name: []const u8,        // Interface name (eth0, wlan0, etc.)
    ipv4_address: ?[4]u8,    // IPv4 address if available
    ipv6_address: ?[16]u8,   // IPv6 address if available
    is_default: bool,        // Is default route interface
    is_active: bool,         // Interface is up and running
    priority: u8,            // Priority for selection (0-255)
};
```

## Error Handling

### DHT Protocol Errors
- **Message Parsing Errors**: Log and ignore malformed messages
- **Routing Table Full**: Implement LRU eviction for questionable nodes
- **Network Timeouts**: Mark nodes as questionable, retry with backoff
- **Invalid Node IDs**: Reject and log suspicious node information

### Bootstrap System Errors
- **Server Unreachable**: Try alternative bootstrap methods (mDNS, UPnP)
- **Invalid Peer Lists**: Parse what's valid, log errors for invalid entries
- **Connection Failures**: Implement exponential backoff with maximum retry limits
- **Network Changes**: Detect and adapt to interface changes automatically

### Network Interface Errors
- **Interface Enumeration Failure**: Fall back to system commands
- **Permission Errors**: Gracefully degrade to available interfaces
- **IPv6 Unavailable**: Continue with IPv4-only operation
- **Dynamic Changes**: Monitor and adapt to network topology changes

## Testing Strategy

### Unit Tests
1. **DHT Message Handlers**
   - Test each handler with valid and invalid messages
   - Verify routing table updates
   - Test error conditions and edge cases

2. **Bootstrap Peer Processing**
   - Test peer list parsing with various formats
   - Verify connection retry logic
   - Test failure handling and recovery

3. **Network Interface Detection**
   - Mock system interfaces for testing
   - Test IPv4/IPv6 detection logic
   - Verify interface priority ranking

### Integration Tests
1. **DHT Protocol Flow**
   - Multi-node DHT network simulation
   - Test ping/pong exchanges between nodes
   - Verify find_node lookup operations

2. **Bootstrap Network Entry**
   - Test new node joining via bootstrap
   - Verify peer discovery and connection
   - Test fallback mechanisms

3. **Network Resilience**
   - Test interface changes during operation
   - Verify recovery from network partitions
   - Test graceful degradation scenarios

### Performance Tests
1. **DHT Lookup Performance**
   - Measure lookup latency with various network sizes
   - Test concurrent lookup operations
   - Verify routing table efficiency

2. **Bootstrap Connection Speed**
   - Measure time to establish initial connections
   - Test with various bootstrap server loads
   - Verify connection retry performance

3. **Memory and CPU Usage**
   - Profile routing table memory usage
   - Monitor message processing overhead
   - Test long-running stability

The implementation will maintain backward compatibility with existing P2P infrastructure while adding the missing functionality needed for production-ready networking.