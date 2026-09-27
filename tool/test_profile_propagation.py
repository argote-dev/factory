"""Exercise VM Service HTTP response/error handling without a Flutter build."""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import threading
import unittest
from urllib.parse import parse_qs, urlsplit

from profile_propagation import rpc


class ServiceHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        request = urlsplit(self.path)
        params = parse_qs(request.query)
        if request.path == "/token/ext.factory.profilePropagation":
            response = {"result": {"p50Us": 12.5, "samples": 40}}
        elif params.get("recordedStreams") == ["[Dart]"]:
            response = {"result": {"type": "Success"}}
        else:
            response = {"error": {"code": -32602, "message": "Invalid params"}}
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def log_message(self, *args):
        pass


class VmServiceContractTest(unittest.TestCase):
    def test_extension_result_and_rpc_errors_are_not_silently_accepted(self):
        server = HTTPServer(("127.0.0.1", 0), ServiceHandler)
        worker = threading.Thread(target=server.serve_forever)
        worker.start()
        uri = f"http://127.0.0.1:{server.server_port}/token/"
        try:
            self.assertEqual(rpc(uri, "ext.factory.profilePropagation", size=10),
                             {"p50Us": 12.5, "samples": 40})
            self.assertEqual(rpc(uri, "setVMTimelineFlags", recordedStreams="[Dart]"),
                             {"type": "Success"})
            with self.assertRaisesRegex(RuntimeError, "Invalid params"):
                rpc(uri, "setVMTimelineFlags", recordedStreams='["Dart"]')
        finally:
            server.shutdown()
            worker.join()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
