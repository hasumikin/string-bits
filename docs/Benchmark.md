## Benchmark

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
(cd tmp/x86_64-linux/string_bits/4.0.4 && /usr/bin/gmake install sitearchdir=../../../../lib/string_bits sitelibdir=../../../../lib/string_bits target_prefix=)
/usr/bin/install -c -m 0755 string_bits.so ../../../../lib/string_bits
cp tmp/x86_64-linux/string_bits/4.0.4/string_bits.so tmp/x86_64-linux/stage/lib/string_bits/string_bits.so

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_and.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_AND ===
Warming up --------------------------------------
            baseline     12.779 i/s -      14.000 times in 1.095528s (78.25ms/i)
         string_bits    12.798k i/s -     13.221k times in 1.033012s (78.13μs/i)
Calculating -------------------------------------
            baseline     13.726 i/s -      38.000 times in 2.768369s (72.85ms/i)
         string_bits    12.979k i/s -     38.395k times in 2.958265s (77.05μs/i)

Comparison:
            baseline:        13.7 i/s 
         string_bits:     12978.9 i/s - 945.54x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_and.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.962 i/s -      32.000 times in 1.033513s (32.30ms/i)
         string_bits    13.661k i/s -     14.927k times in 1.092673s (73.20μs/i)
Calculating -------------------------------------
            baseline     34.257 i/s -      92.000 times in 2.685547s (29.19ms/i)
         string_bits    13.176k i/s -     40.982k times in 3.110338s (75.90μs/i)

Comparison:
            baseline:        34.3 i/s 
         string_bits:     13176.1 i/s - 384.62x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_at.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_AT ===
Warming up --------------------------------------
            baseline     12.881 i/s -      14.000 times in 1.086913s (77.64ms/i)
         string_bits     22.280 i/s -      24.000 times in 1.077217s (44.88ms/i)
Calculating -------------------------------------
            baseline     12.089 i/s -      38.000 times in 3.143246s (82.72ms/i)
         string_bits     22.467 i/s -      66.000 times in 2.937635s (44.51ms/i)

Comparison:
            baseline:        12.1 i/s 
         string_bits:        22.5 i/s - 1.86x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_at.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     38.190 i/s -      40.000 times in 1.047396s (26.18ms/i)
         string_bits     41.553 i/s -      45.000 times in 1.082954s (24.07ms/i)
Calculating -------------------------------------
            baseline     39.144 i/s -     114.000 times in 2.912317s (25.55ms/i)
         string_bits     40.433 i/s -     124.000 times in 3.066835s (24.73ms/i)

Comparison:
            baseline:        39.1 i/s 
         string_bits:        40.4 i/s - 1.03x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_count.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_COUNT ===
Warming up --------------------------------------
            baseline     19.936 i/s -      20.000 times in 1.003202s (50.16ms/i)
         string_bits     6.468k i/s -      6.996k times in 1.081593s (154.60μs/i)
Calculating -------------------------------------
            baseline     22.233 i/s -      59.000 times in 2.653716s (44.98ms/i)
         string_bits     6.369k i/s -     19.404k times in 3.046750s (157.02μs/i)

Comparison:
            baseline:        22.2 i/s 
         string_bits:      6368.8 i/s - 286.46x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_count.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     25.078 i/s -      27.000 times in 1.076656s (39.88ms/i)
         string_bits     5.666k i/s -      6.204k times in 1.094912s (176.48μs/i)
Calculating -------------------------------------
            baseline     23.132 i/s -      75.000 times in 3.242197s (43.23ms/i)
         string_bits     6.171k i/s -     16.998k times in 2.754630s (162.06μs/i)

Comparison:
            baseline:        23.1 i/s 
         string_bits:      6170.7 i/s - 266.76x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_not.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_NOT ===
Warming up --------------------------------------
            baseline     14.285 i/s -      16.000 times in 1.120019s (70.00ms/i)
         string_bits    16.879k i/s -     17.370k times in 1.029116s (59.25μs/i)
Calculating -------------------------------------
            baseline     14.527 i/s -      42.000 times in 2.891255s (68.84ms/i)
         string_bits    17.515k i/s -     50.635k times in 2.890920s (57.09μs/i)

Comparison:
            baseline:        14.5 i/s 
         string_bits:     17515.2 i/s - 1205.73x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_not.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     26.291 i/s -      27.000 times in 1.026950s (38.04ms/i)
         string_bits    16.927k i/s -     18.337k times in 1.083325s (59.08μs/i)
Calculating -------------------------------------
            baseline     29.842 i/s -      78.000 times in 2.613792s (33.51ms/i)
         string_bits    16.905k i/s -     50.779k times in 3.003755s (59.15μs/i)

Comparison:
            baseline:        29.8 i/s 
         string_bits:     16905.2 i/s - 566.49x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_or.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_OR ===
Warming up --------------------------------------
            baseline     13.981 i/s -      14.000 times in 1.001356s (71.53ms/i)
         string_bits    12.953k i/s -     13.990k times in 1.080035s (77.20μs/i)
Calculating -------------------------------------
            baseline     13.437 i/s -      41.000 times in 3.051257s (74.42ms/i)
         string_bits    13.346k i/s -     38.859k times in 2.911718s (74.93μs/i)

Comparison:
            baseline:        13.4 i/s 
         string_bits:     13345.7 i/s - 993.20x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_or.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.784 i/s -      32.000 times in 1.039490s (32.48ms/i)
         string_bits    13.625k i/s -     14.762k times in 1.083426s (73.39μs/i)
Calculating -------------------------------------
            baseline     34.250 i/s -      92.000 times in 2.686152s (29.20ms/i)
         string_bits    13.346k i/s -     40.875k times in 3.062676s (74.93μs/i)

Comparison:
            baseline:        34.2 i/s 
         string_bits:     13346.2 i/s - 389.67x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_run_count.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_RUN_COUNT ===
Warming up --------------------------------------
            baseline    279.829 i/s -     290.000 times in 1.036347s (3.57ms/i)
         string_bits    452.353 i/s -     460.000 times in 1.016904s (2.21ms/i)
Calculating -------------------------------------
            baseline    252.340 i/s -     839.000 times in 3.324879s (3.96ms/i)
         string_bits    403.863 i/s -      1.357k times in 3.360054s (2.48ms/i)

Comparison:
            baseline:       252.3 i/s 
         string_bits:       403.9 i/s - 1.60x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_run_count.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    894.481 i/s -     968.000 times in 1.082192s (1.12ms/i)
         string_bits    567.019 i/s -     580.000 times in 1.022894s (1.76ms/i)
Calculating -------------------------------------
            baseline    815.533 i/s -      2.683k times in 3.289873s (1.23ms/i)
         string_bits    548.217 i/s -      1.701k times in 3.102788s (1.82ms/i)

Comparison:
            baseline:       815.5 i/s 
         string_bits:       548.2 i/s - 1.49x  slower

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_slice.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_SLICE ===
Warming up --------------------------------------
            baseline     75.417 i/s -      80.000 times in 1.060772s (13.26ms/i)
         string_bits    442.004 i/s -     480.000 times in 1.085964s (2.26ms/i)
Calculating -------------------------------------
            baseline     78.098 i/s -     226.000 times in 2.893805s (12.80ms/i)
         string_bits    422.637 i/s -      1.326k times in 3.137442s (2.37ms/i)

Comparison:
            baseline:        78.1 i/s 
         string_bits:       422.6 i/s - 5.41x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_slice.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    301.735 i/s -     330.000 times in 1.093673s (3.31ms/i)
         string_bits    491.010 i/s -     506.000 times in 1.030529s (2.04ms/i)
Calculating -------------------------------------
            baseline    314.207 i/s -     905.000 times in 2.880263s (3.18ms/i)
         string_bits    495.778 i/s -      1.473k times in 2.971088s (2.02ms/i)

Comparison:
            baseline:       314.2 i/s 
         string_bits:       495.8 i/s - 1.58x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_splice.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_SPLICE ===
Warming up --------------------------------------
            baseline     79.957 i/s -      80.000 times in 1.000535s (12.51ms/i)
         string_bits     39.949 i/s -      40.000 times in 1.001282s (25.03ms/i)
Calculating -------------------------------------
            baseline     79.546 i/s -     239.000 times in 3.004550s (12.57ms/i)
         string_bits     40.896 i/s -     119.000 times in 2.909796s (24.45ms/i)

Comparison:
            baseline:        79.5 i/s 
         string_bits:        40.9 i/s - 1.95x  slower

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_splice.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    186.986 i/s -     198.000 times in 1.058904s (5.35ms/i)
         string_bits     43.694 i/s -      44.000 times in 1.006997s (22.89ms/i)
Calculating -------------------------------------
            baseline    196.858 i/s -     560.000 times in 2.844688s (5.08ms/i)
         string_bits     45.776 i/s -     131.000 times in 2.861747s (21.85ms/i)

Comparison:
            baseline:       196.9 i/s 
         string_bits:        45.8 i/s - 4.30x  slower

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_xor.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_XOR ===
Warming up --------------------------------------
            baseline     11.106 i/s -      12.000 times in 1.080528s (90.04ms/i)
         string_bits    15.910k i/s -     16.962k times in 1.066118s (62.85μs/i)
Calculating -------------------------------------
            baseline     12.364 i/s -      33.000 times in 2.668985s (80.88ms/i)
         string_bits    14.905k i/s -     47.730k times in 3.202252s (67.09μs/i)

Comparison:
            baseline:        12.4 i/s 
         string_bits:     14905.1 i/s - 1205.50x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_xor.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     26.733 i/s -      27.000 times in 1.009978s (37.41ms/i)
         string_bits    15.632k i/s -     15.830k times in 1.012688s (63.97μs/i)
Calculating -------------------------------------
            baseline     33.642 i/s -      80.000 times in 2.377970s (29.72ms/i)
         string_bits    14.593k i/s -     46.894k times in 3.213474s (68.53μs/i)

Comparison:
            baseline:        33.6 i/s 
         string_bits:     14592.9 i/s - 433.77x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bloom_filter.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BLOOM_FILTER ===
Warming up --------------------------------------
            baseline      8.012 i/s -       9.000 times in 1.123255s (124.81ms/i)
         string_bits      8.341 i/s -       9.000 times in 1.079033s (119.89ms/i)
Calculating -------------------------------------
            baseline      7.923 i/s -      24.000 times in 3.029115s (126.21ms/i)
         string_bits      9.368 i/s -      25.000 times in 2.668701s (106.75ms/i)

Comparison:
            baseline:         7.9 i/s 
         string_bits:         9.4 i/s - 1.18x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bloom_filter.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     12.703 i/s -      14.000 times in 1.102118s (78.72ms/i)
         string_bits     14.814 i/s -      16.000 times in 1.080033s (67.50ms/i)
Calculating -------------------------------------
            baseline     14.298 i/s -      38.000 times in 2.657658s (69.94ms/i)
         string_bits     15.481 i/s -      44.000 times in 2.842114s (64.59ms/i)

Comparison:
            baseline:        14.3 i/s 
         string_bits:        15.5 i/s - 1.08x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== CLEAR_BIT ===
Warming up --------------------------------------
            baseline      9.135 i/s -      10.000 times in 1.094633s (109.46ms/i)
         string_bits     20.006 i/s -      21.000 times in 1.049694s (49.99ms/i)
Calculating -------------------------------------
            baseline      9.455 i/s -      27.000 times in 2.855774s (105.77ms/i)
         string_bits     21.381 i/s -      60.000 times in 2.806217s (46.77ms/i)

Comparison:
            baseline:         9.5 i/s 
         string_bits:        21.4 i/s - 2.26x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.136 i/s -      33.000 times in 1.095031s (33.18ms/i)
         string_bits     34.617 i/s -      36.000 times in 1.039962s (28.89ms/i)
Calculating -------------------------------------
            baseline     23.741 i/s -      90.000 times in 3.790862s (42.12ms/i)
         string_bits     34.582 i/s -     103.000 times in 2.978459s (28.92ms/i)

Comparison:
            baseline:        23.7 i/s 
         string_bits:        34.6 i/s - 1.46x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== CLEAR_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.588 i/s -       2.000 times in 1.259692s (629.85ms/i)
         string_bits     67.021 i/s -      70.000 times in 1.044451s (14.92ms/i)
Calculating -------------------------------------
            baseline      1.580 i/s -       4.000 times in 2.531669s (632.92ms/i)
         string_bits     64.571 i/s -     201.000 times in 3.112830s (15.49ms/i)

Comparison:
            baseline:         1.6 i/s 
         string_bits:        64.6 i/s - 40.87x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      3.621 i/s -       4.000 times in 1.104700s (276.17ms/i)
         string_bits     65.897 i/s -      70.000 times in 1.062263s (15.18ms/i)
Calculating -------------------------------------
            baseline      3.257 i/s -      10.000 times in 3.070477s (307.05ms/i)
         string_bits     71.169 i/s -     197.000 times in 2.768062s (14.05ms/i)

Comparison:
            baseline:         3.3 i/s 
         string_bits:        71.2 i/s - 21.85x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== EACH_BIT ===
Warming up --------------------------------------
            baseline     17.655 i/s -      18.000 times in 1.019553s (56.64ms/i)
         string_bits     94.288 i/s -      99.000 times in 1.049976s (10.61ms/i)
Calculating -------------------------------------
            baseline     17.079 i/s -      52.000 times in 3.044739s (58.55ms/i)
         string_bits    107.517 i/s -     282.000 times in 2.622836s (9.30ms/i)

Comparison:
            baseline:        17.1 i/s 
         string_bits:       107.5 i/s - 6.30x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     54.642 i/s -      60.000 times in 1.098055s (18.30ms/i)
         string_bits     92.422 i/s -      99.000 times in 1.071175s (10.82ms/i)
Calculating -------------------------------------
            baseline     56.286 i/s -     163.000 times in 2.895904s (17.77ms/i)
         string_bits     95.437 i/s -     277.000 times in 2.902450s (10.48ms/i)

Comparison:
            baseline:        56.3 i/s 
         string_bits:        95.4 i/s - 1.70x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit_run.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== EACH_BIT_RUN ===
Warming up --------------------------------------
            baseline      9.821 i/s -      10.000 times in 1.018180s (101.82ms/i)
         string_bits     44.510 i/s -      45.000 times in 1.011016s (22.47ms/i)
Calculating -------------------------------------
            baseline     10.884 i/s -      29.000 times in 2.664421s (91.88ms/i)
         string_bits     53.304 i/s -     133.000 times in 2.495141s (18.76ms/i)

Comparison:
            baseline:        10.9 i/s 
         string_bits:        53.3 i/s - 4.90x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit_run.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     31.674 i/s -      33.000 times in 1.041859s (31.57ms/i)
         string_bits     49.075 i/s -      50.000 times in 1.018852s (20.38ms/i)
Calculating -------------------------------------
            baseline     34.602 i/s -      95.000 times in 2.745477s (28.90ms/i)
         string_bits     53.505 i/s -     147.000 times in 2.747425s (18.69ms/i)

Comparison:
            baseline:        34.6 i/s 
         string_bits:        53.5 i/s - 1.55x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== FLIP_BIT ===
Warming up --------------------------------------
            baseline      9.595 i/s -      10.000 times in 1.042207s (104.22ms/i)
         string_bits     21.750 i/s -      24.000 times in 1.103433s (45.98ms/i)
Calculating -------------------------------------
            baseline      9.700 i/s -      28.000 times in 2.886612s (103.09ms/i)
         string_bits     21.953 i/s -      65.000 times in 2.960858s (45.55ms/i)

Comparison:
            baseline:         9.7 i/s 
         string_bits:        22.0 i/s - 2.26x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     25.367 i/s -      27.000 times in 1.064389s (39.42ms/i)
         string_bits     34.720 i/s -      36.000 times in 1.036865s (28.80ms/i)
Calculating -------------------------------------
            baseline     27.786 i/s -      76.000 times in 2.735215s (35.99ms/i)
         string_bits     37.587 i/s -     104.000 times in 2.766935s (26.61ms/i)

Comparison:
            baseline:        27.8 i/s 
         string_bits:        37.6 i/s - 1.35x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== FLIP_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.511 i/s -       2.000 times in 1.323695s (661.85ms/i)
         string_bits     64.402 i/s -      70.000 times in 1.086926s (15.53ms/i)
Calculating -------------------------------------
            baseline      1.431 i/s -       4.000 times in 2.795794s (698.95ms/i)
         string_bits     61.084 i/s -     193.000 times in 3.159583s (16.37ms/i)

Comparison:
            baseline:         1.4 i/s 
         string_bits:        61.1 i/s - 42.69x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      3.599 i/s -       4.000 times in 1.111454s (277.86ms/i)
         string_bits     61.714 i/s -      63.000 times in 1.020841s (16.20ms/i)
Calculating -------------------------------------
            baseline      3.190 i/s -      10.000 times in 3.134321s (313.43ms/i)
         string_bits     72.126 i/s -     185.000 times in 2.564973s (13.86ms/i)

Comparison:
            baseline:         3.2 i/s 
         string_bits:        72.1 i/s - 22.61x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/hamming.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== HAMMING ===
Warming up --------------------------------------
            baseline     38.630 i/s -      40.000 times in 1.035472s (25.89ms/i)
         string_bits    943.746 i/s -     979.000 times in 1.037355s (1.06ms/i)
Calculating -------------------------------------
            baseline     40.465 i/s -     115.000 times in 2.841937s (24.71ms/i)
         string_bits    934.697 i/s -      2.831k times in 3.028787s (1.07ms/i)

Comparison:
            baseline:        40.5 i/s 
         string_bits:       934.7 i/s - 23.10x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/hamming.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    355.504 i/s -     380.000 times in 1.068904s (2.81ms/i)
         string_bits     1.088k i/s -      1.188k times in 1.091992s (919.19μs/i)
Calculating -------------------------------------
            baseline    365.838 i/s -      1.066k times in 2.913862s (2.73ms/i)
         string_bits     1.232k i/s -      3.263k times in 2.647759s (811.45μs/i)

Comparison:
            baseline:       365.8 i/s 
         string_bits:      1232.4 i/s - 3.37x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/jaccard.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== JACCARD ===
Warming up --------------------------------------
            baseline     93.676 i/s -     100.000 times in 1.067504s (10.68ms/i)
         string_bits    18.819k i/s -     19.474k times in 1.034809s (53.14μs/i)
Calculating -------------------------------------
            baseline     88.571 i/s -     281.000 times in 3.172590s (11.29ms/i)
         string_bits    17.939k i/s -     56.456k times in 3.147074s (55.74μs/i)

Comparison:
            baseline:        88.6 i/s 
         string_bits:     17939.2 i/s - 202.54x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/jaccard.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    190.566 i/s -     209.000 times in 1.096734s (5.25ms/i)
         string_bits    17.079k i/s -     18.460k times in 1.080853s (58.55μs/i)
Calculating -------------------------------------
            baseline    179.168 i/s -     571.000 times in 3.186948s (5.58ms/i)
         string_bits    18.708k i/s -     51.237k times in 2.738748s (53.45μs/i)

Comparison:
            baseline:       179.2 i/s 
         string_bits:     18708.2 i/s - 104.42x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/rle.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== RLE ===
Warming up --------------------------------------
            baseline      9.779 i/s -      10.000 times in 1.022633s (102.26ms/i)
            each_bit     15.122 i/s -      16.000 times in 1.058037s (66.13ms/i)
        each_bit_run     43.129 i/s -      44.000 times in 1.020206s (23.19ms/i)
Calculating -------------------------------------
            baseline     10.180 i/s -      29.000 times in 2.848650s (98.23ms/i)
            each_bit     15.412 i/s -      45.000 times in 2.919724s (64.88ms/i)
        each_bit_run     43.421 i/s -     129.000 times in 2.970944s (23.03ms/i)

Comparison:
            baseline:        10.2 i/s 
            each_bit:        15.4 i/s - 1.51x  faster
        each_bit_run:        43.4 i/s - 4.27x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/rle.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     35.172 i/s -      36.000 times in 1.023541s (28.43ms/i)
            each_bit     22.060 i/s -      24.000 times in 1.087956s (45.33ms/i)
        each_bit_run     44.852 i/s -      48.000 times in 1.070184s (22.30ms/i)
Calculating -------------------------------------
            baseline     32.266 i/s -     105.000 times in 3.254242s (30.99ms/i)
            each_bit     24.304 i/s -      66.000 times in 2.715656s (41.15ms/i)
        each_bit_run     47.181 i/s -     134.000 times in 2.840105s (21.19ms/i)

Comparison:
            baseline:        32.3 i/s 
            each_bit:        24.3 i/s - 1.33x  slower
        each_bit_run:        47.2 i/s - 1.46x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT ===
Warming up --------------------------------------
            baseline      9.645 i/s -      10.000 times in 1.036855s (103.69ms/i)
         string_bits     21.906 i/s -      24.000 times in 1.095602s (45.65ms/i)
Calculating -------------------------------------
            baseline     10.819 i/s -      28.000 times in 2.588007s (92.43ms/i)
         string_bits     19.744 i/s -      65.000 times in 3.292163s (50.65ms/i)

Comparison:
            baseline:        10.8 i/s 
         string_bits:        19.7 i/s - 1.82x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.339 i/s -      33.000 times in 1.087727s (32.96ms/i)
         string_bits     29.080 i/s -      32.000 times in 1.100424s (34.39ms/i)
Calculating -------------------------------------
            baseline     25.468 i/s -      91.000 times in 3.573157s (39.27ms/i)
         string_bits     37.182 i/s -      87.000 times in 2.339853s (26.89ms/i)

Comparison:
            baseline:        25.5 i/s 
         string_bits:        37.2 i/s - 1.46x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_offsets.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT_OFFSETS ===
Warming up --------------------------------------
            baseline     13.843 i/s -      14.000 times in 1.011319s (72.24ms/i)
         string_bits    244.288 i/s -     264.000 times in 1.080693s (4.09ms/i)
Calculating -------------------------------------
            baseline     12.498 i/s -      41.000 times in 3.280649s (80.02ms/i)
         string_bits    235.400 i/s -     732.000 times in 3.109597s (4.25ms/i)

Comparison:
            baseline:        12.5 i/s 
         string_bits:       235.4 i/s - 18.84x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_offsets.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     51.292 i/s -      55.000 times in 1.072296s (19.50ms/i)
         string_bits    215.146 i/s -     220.000 times in 1.022559s (4.65ms/i)
Calculating -------------------------------------
            baseline     48.306 i/s -     153.000 times in 3.167289s (20.70ms/i)
         string_bits    232.536 i/s -     645.000 times in 2.773770s (4.30ms/i)

Comparison:
            baseline:        48.3 i/s 
         string_bits:       232.5 i/s - 4.81x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.635 i/s -       2.000 times in 1.223029s (611.51ms/i)
         string_bits     57.198 i/s -      60.000 times in 1.048982s (17.48ms/i)
Calculating -------------------------------------
            baseline      1.668 i/s -       4.000 times in 2.397903s (599.48ms/i)
         string_bits     64.146 i/s -     171.000 times in 2.665789s (15.59ms/i)

Comparison:
            baseline:         1.7 i/s 
         string_bits:        64.1 i/s - 38.45x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      3.754 i/s -       4.000 times in 1.065525s (266.38ms/i)
         string_bits     62.191 i/s -      63.000 times in 1.013004s (16.08ms/i)
Calculating -------------------------------------
            baseline      3.525 i/s -      11.000 times in 3.120890s (283.72ms/i)
         string_bits     66.876 i/s -     186.000 times in 2.781284s (14.95ms/i)

Comparison:
            baseline:         3.5 i/s 
         string_bits:        66.9 i/s - 18.97x  faster

/home/hasumi/.rbenv/versions/4.0.4/bin/ruby benchmark/allocation.rb

Allocation benchmark
Ruby 4.0.4 | string_bits dev
                                                                             allocs
  ===================================================================================

  bit_count (1MB data)
  -----------------------------------------------------------------------------------
  baseline:    each_byte { b.to_s(2).count("1") }                           1000014
  baseline:    bytes.sum { ... }  (+ Array alloc)                           1000005
  string_bits: bit_count                                                          3

  bulk bitwise AND (1MB + 1MB)
  -----------------------------------------------------------------------------------
  baseline:    bytes/zip/map/pack  (natural)                                1000012
  baseline:    dup + setbyte loop  (optimised)                                   11
  string_bits: bit_and  (returns new String)                                      5
  string_bits: bit_and! (in-place, needs dup)                                     5

  bit_slice x1000 (64-bit unaligned windows, 100KB data)
  -----------------------------------------------------------------------------------
  baseline:    byte-shift loop x1000                                           3007
  string_bits: bit_slice x1000                                                 1003

  set-bit iteration (1M bits, ~50% set)
  -----------------------------------------------------------------------------------
  baseline:    manual byte loop + conditional push                                6
  string_bits: each_set_bit_offset { block }  (yields Fixnum)                     6
  string_bits: set_bit_offsets  (-> Array)                                        6

  run-length encoding -- validity bitmap (~100KB, ~1,960 runs)
  -----------------------------------------------------------------------------------
  baseline:    each_byte + bit loop                                            1968
  string_bits: each_bit { block }                                              1964
  string_bits: each_bit_run { block }                                          1964

  range mutation x1000 (64-bit ranges in 100KB bitmap)
  -----------------------------------------------------------------------------------
  baseline:    range.each { set_bit logic } x1000                                 6
  string_bits: set_bit(range) x1000                                               7

  Array#mask (100K elements, ~50% masked)
  -----------------------------------------------------------------------------------
  baseline:    each_byte + byte[bit] loop                                         7
  string_bits: mask  (returns new Array)                                          6
  string_bits: mask! (in-place, needs dup)                                        7
```
