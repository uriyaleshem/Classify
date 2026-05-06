from socket import socket
from tcp_by_size import send_with_size, recv_by_size
from hashlib import sha256
from cryptography.hazmat.primitives.asymmetric import dh
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_public_key, load_pem_parameters
from cryptography.hazmat.backends import default_backend


# RFC 3526 group 14 (2048-bit MODP). Using a fixed well-known group avoids
# generating DH parameters on every connection, which can make the client time out.
RFC3526_GROUP14_P = int(
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
    "29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
    "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
    "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D"
    "C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"
    "83655D23DCA3AD961C62F356208552BB9ED529077096966D"
    "670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B"
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9"
    "DE2BCBF6955817183995497CEA956AE515D2261898FA0510"
    "15728E5A8AACAA68FFFFFFFFFFFFFFFF",
    16,
)


DH_PARAMETERS = dh.DHParameterNumbers(RFC3526_GROUP14_P, 2).parameters(default_backend())

def DH_client(sock : socket) -> bytes:
    """
    :param params: a string that contains the g number and the p number
    :return: nothing
    """
    server_hello = recv_by_size(sock)
    if not server_hello or b'|' not in server_hello:
        raise ConnectionError("DH handshake failed: invalid server hello")

    params, server_public = server_hello.split(b'|', 1)
    params = load_pem_parameters(params)
    server_public = load_pem_public_key(server_public)
    private_key = params.generate_private_key()
    public_key = private_key.public_key()
    pk_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    send_with_size(sock, pk_bytes)
    shared_secret = private_key.exchange(server_public)
    return sha256(shared_secret).digest()


def DH_server(sock: socket) -> bytes:
    params = DH_PARAMETERS
    private_key = params.generate_private_key()
    public_key = private_key.public_key()
    pk_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    prm_bytes = params.parameter_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.ParameterFormat.PKCS3
    )
    send_with_size(sock, prm_bytes + b'|' + pk_bytes)
    client_public_key = load_pem_public_key(recv_by_size(sock))
    shared_secret = private_key.exchange(client_public_key)
    return sha256(shared_secret).digest()
