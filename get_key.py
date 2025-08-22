import base64
from urllib.parse import urlparse, parse_qs
from message_pb2 import Payload

class OTPAuthError(Exception):
    pass


def extract_data(link: str) -> bytes:
    u = urlparse(link)

    if u.scheme != "otpauth-migration":
        raise OTPAuthError(f"Unknown scheme: {u.scheme}")
    if u.netloc != "offline":
        raise OTPAuthError(f"Unknown host: {u.netloc}")

    query_params = parse_qs(u.query)
    data_list = query_params.get("data")

    if not data_list:
        raise OTPAuthError("Missing 'data' query parameter")

    data = data_list[0].replace(" ", "+")  # Fix spaces to plus sign
    try:  
        return base64.b64decode(data)
    except Exception as e:
        raise OTPAuthError(f"Base64 decode failed: {str(e)}")


def unmarshal(data: bytes) -> Payload:
    p = Payload()
    try:
        p.ParseFromString(data)
        return p
    except Exception as e:
        raise ValueError(f"Failed to parse Payload: {e}")

link = "" #Paste your copied QR link here

accounts = extract_data(link)
print(accounts)

payload = unmarshal(accounts)
accounts_array = payload.otp_parameters
print(len(accounts_array))
secret = accounts_array[0].secret
print(base64.b32encode(secret))
