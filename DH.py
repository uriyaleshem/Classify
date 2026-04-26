from socket import socket
from tcp_by_size import send_with_size, recv_by_size
from hashlib import sha256
from cryptography.hazmat.primitives.asymmetric import dh
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_public_key, load_pem_parameters

def DH_client(sock : socket) -> bytes:
    """
    :param params: a string that contains the g number and the p number
    :return: nothing
    """
    params, server_public = recv_by_size(sock).split(b'|')
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
    params = dh.generate_parameters(generator=2, key_size=2048)
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