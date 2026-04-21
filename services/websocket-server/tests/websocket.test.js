const WebSocket = require("ws");
const { broadcast } = require("../src/websocket");

function makeMockWss(clients) {
  return { clients: new Set(clients) };
}

function makeMockClient(readyState) {
  return { readyState, send: jest.fn() };
}

test("broadcast sends to OPEN clients", () => {
  const open   = makeMockClient(WebSocket.OPEN);    // readyState 1
  const closed = makeMockClient(WebSocket.CLOSED);  // readyState 3
  const wss    = makeMockWss([open, closed]);

  broadcast(wss, { type: "event_counts", data: { click: 5 } });

  expect(open.send).toHaveBeenCalledTimes(1);
  expect(closed.send).not.toHaveBeenCalled();

  const sent = JSON.parse(open.send.mock.calls[0][0]);
  expect(sent.type).toBe("event_counts");
  expect(sent.data.click).toBe(5);
});

test("broadcast sends nothing when no clients connected", () => {
  const wss = makeMockWss([]);
  expect(() => broadcast(wss, { type: "event_counts", data: {} })).not.toThrow();
});

test("broadcast serialises payload to JSON string", () => {
  const client = makeMockClient(WebSocket.OPEN);
  const wss    = makeMockWss([client]);
  const payload = { type: "event_counts", data: { purchase: 12 } };

  broadcast(wss, payload);

  expect(typeof client.send.mock.calls[0][0]).toBe("string");
  expect(JSON.parse(client.send.mock.calls[0][0])).toEqual(payload);
});