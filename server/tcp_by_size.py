__author__ = 'Yossi'

# from  tcp_by_size import send_with_size ,recv_by_size
import socket


SIZE_HEADER_FORMAT = "000000000~" # n digits for data size + one delimiter
size_header_size = len(SIZE_HEADER_FORMAT)
TCP_DEBUG = False
LEN_TO_PRINT = 100
MAX_FRAME_SIZE = 64 * 1024 * 1024  # encrypted JSON + base64 uploads can be larger than raw files


def recv_by_size(sock, max_frame_size=MAX_FRAME_SIZE):
    size_header = b''
    data_len = 0
    try:
        while len(size_header) < size_header_size:
            _s = sock.recv(size_header_size - len(size_header))
            if _s == b'':
                size_header = b''
                break
            size_header += _s

        data = b''
        if size_header != b'':
            if len(size_header) != size_header_size or size_header[-1:] != b'|':
                return b''

            size_digits = size_header[:size_header_size - 1]
            if not size_digits.isdigit():
                return b''

            data_len = int(size_digits)
            if data_len < 0 or data_len > max_frame_size:
                return b''

            chunks = []
            received = 0
            while received < data_len:
                _d = sock.recv(min(64 * 1024, data_len - received))
                if _d == b'':
                    chunks = []
                    break
                chunks.append(_d)
                received += len(_d)
            data = b''.join(chunks)
    except socket.timeout:
        return b''
    except OSError:
        return b''

    if  TCP_DEBUG and size_header != b'':
        print ("\nRecv11(%s)>>>" % (size_header,), end='')
        print ("%s"%(data[:min(len(data),LEN_TO_PRINT)],))
    if data_len != len(data):
        data=b'' # Partial data is like no data !
    return data





def send_with_size(sock, bdata):
    if isinstance(bdata, str):
        bdata = bdata.encode()
    len_data = len(bdata)
    if len_data > MAX_FRAME_SIZE:
        raise ValueError("TCP frame is too large")
    header_data = str(len(bdata)).zfill(size_header_size - 1) + "|"

    bytea = bytearray(header_data,encoding='utf8') + bdata

    sock.sendall(bytea)
    if TCP_DEBUG and  len_data > 0:
        print ("\nSent(%s)>>>" % (len_data,), end='')
        print ("%s"%(bytea[:min(len(bytea),LEN_TO_PRINT)],))
