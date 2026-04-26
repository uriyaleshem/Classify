from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend


def encrypt_message(aes_key, data):
    if isinstance(data, str):
        data = data.encode()

    nonce = os.urandom(12)
    aesgcm = AESGCM(aes_key)
    ciphertext = aesgcm.encrypt(nonce, data, None)
    return nonce + ciphertext


def decrypt_message(aes_key, data):
    nonce = data[:12]
    ciphertext = data[12:]
    aesgcm = AESGCM(aes_key)
    plaintext = aesgcm.decrypt(nonce, ciphertext, None)
    return plaintext


def get_aes_key(shared_key_int):
    shared_bytes = str(shared_key_int).encode()

    digest = hashes.Hash(hashes.SHA256(), backend=default_backend())
    digest.update(shared_bytes)
    return digest.finalize()
