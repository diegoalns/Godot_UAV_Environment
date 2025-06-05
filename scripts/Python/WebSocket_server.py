import asyncio
import websockets
import json

async def websocket_handler(websocket):
    print("Client connected!")
    try:
        async for message in websocket:
            print(f"Received from client: {message}")
            
            try:
                # Parse the JSON message
                data = json.loads(message)
                
                # Check for drone creation messages
                if data.get("type") == "drone_created":
                    drone_id = data.get("drone_id")
                    model = data.get("model")
                    start = data.get("start_position")
                    end = data.get("end_position")
                    
                    print(f"Drone created: {drone_id} ({model})")
                    print(f"  Start: {start}")
                    print(f"  End: {end}")
                    
                    # Send acknowledgment
                    response = {
                        "type": "drone_creation_ack",
                        "drone_id": drone_id,
                        "status": "received"
                    }
                    await websocket.send(json.dumps(response))
                else:
                    # Echo other messages
                    await websocket.send(f"Echo: {message}")
            except json.JSONDecodeError:
                # Handle non-JSON messages
                await websocket.send(f"Echo: {message}")
                
    except websockets.ConnectionClosed:
        print("Client disconnected.")

# Start the server on localhost:8765
async def main():
    async with websockets.serve(websocket_handler, 'localhost', 8765):
        print("WebSocket server started on ws://localhost:8765")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())