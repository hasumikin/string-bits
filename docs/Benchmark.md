## Benchmark

Some benchmarks show that the current Ruby with YJIT enabled is faster. Nevertheless, I still believe that the advantage of being able to write code more concisely using the string_bits methods outweighs any drawbacks.

Environment:

```bash
$> uname -a
Linux hasumi-Ubuntu-Desktop 6.17.0-20-generic #20~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Mar 19 01:28:37 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
$> ruby -v
ruby 4.0.4 (2026-05-12 revision b89eb1bcbf) +PRISM [x86_64-linux]
```

Result:

```bash
$> rake benchmark
```
=>
```
```
