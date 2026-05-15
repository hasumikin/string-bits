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
            baseline     12.721 i/s -      14.000 times in 1.100578s (78.61ms/i)
         string_bits    17.415k i/s -     17.540k times in 1.007181s (57.42μs/i)
Calculating -------------------------------------
            baseline     12.862 i/s -      38.000 times in 2.954373s (77.75ms/i)
         string_bits    18.239k i/s -     52.244k times in 2.864345s (54.83μs/i)

Comparison:
            baseline:        12.9 i/s 
         string_bits:     18239.4 i/s - 1418.05x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_and.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.880 i/s -      32.000 times in 1.036270s (32.38ms/i)
         string_bits    18.554k i/s -     19.300k times in 1.040195s (53.90μs/i)
Calculating -------------------------------------
            baseline     31.769 i/s -      92.000 times in 2.895949s (31.48ms/i)
         string_bits    17.568k i/s -     55.662k times in 3.168365s (56.92μs/i)

Comparison:
            baseline:        31.8 i/s 
         string_bits:     17568.1 i/s - 553.00x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_at.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_AT ===
Warming up --------------------------------------
            baseline      9.609 i/s -      10.000 times in 1.040730s (104.07ms/i)
         string_bits     18.969 i/s -      20.000 times in 1.054341s (52.72ms/i)
Calculating -------------------------------------
            baseline     12.476 i/s -      28.000 times in 2.244378s (80.16ms/i)
         string_bits     20.354 i/s -      56.000 times in 2.751330s (49.13ms/i)

Comparison:
            baseline:        12.5 i/s 
         string_bits:        20.4 i/s - 1.63x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_at.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     41.281 i/s -      45.000 times in 1.090081s (24.22ms/i)
         string_bits     40.950 i/s -      45.000 times in 1.098888s (24.42ms/i)
Calculating -------------------------------------
            baseline     39.537 i/s -     123.000 times in 3.110980s (25.29ms/i)
         string_bits     37.296 i/s -     122.000 times in 3.271159s (26.81ms/i)

Comparison:
            baseline:        39.5 i/s 
         string_bits:        37.3 i/s - 1.06x  slower

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_count.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_COUNT ===
Warming up --------------------------------------
            baseline     19.917 i/s -      20.000 times in 1.004151s (50.21ms/i)
         string_bits     5.743k i/s -      6.281k times in 1.093651s (174.12μs/i)
Calculating -------------------------------------
            baseline     20.575 i/s -      59.000 times in 2.867553s (48.60ms/i)
         string_bits     6.024k i/s -     17.229k times in 2.860278s (166.02μs/i)

Comparison:
            baseline:        20.6 i/s 
         string_bits:      6023.5 i/s - 292.76x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_count.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     25.036 i/s -      27.000 times in 1.078434s (39.94ms/i)
         string_bits     6.520k i/s -      7.172k times in 1.099920s (153.36μs/i)
Calculating -------------------------------------
            baseline     23.417 i/s -      75.000 times in 3.202738s (42.70ms/i)
         string_bits     6.525k i/s -     19.561k times in 2.998056s (153.27μs/i)

Comparison:
            baseline:        23.4 i/s 
         string_bits:      6524.6 i/s - 278.62x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_not.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_NOT ===
Warming up --------------------------------------
            baseline     15.965 i/s -      16.000 times in 1.002201s (62.64ms/i)
         string_bits    19.684k i/s -     20.790k times in 1.056205s (50.80μs/i)
Calculating -------------------------------------
            baseline     14.502 i/s -      47.000 times in 3.240843s (68.95ms/i)
         string_bits    18.287k i/s -     59.051k times in 3.229059s (54.68μs/i)

Comparison:
            baseline:        14.5 i/s 
         string_bits:     18287.4 i/s - 1260.99x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_not.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     26.481 i/s -      27.000 times in 1.019606s (37.76ms/i)
         string_bits    19.645k i/s -     20.820k times in 1.059834s (50.90μs/i)
Calculating -------------------------------------
            baseline     33.627 i/s -      79.000 times in 2.349271s (29.74ms/i)
         string_bits    18.634k i/s -     58.933k times in 3.162660s (53.67μs/i)

Comparison:
            baseline:        33.6 i/s 
         string_bits:     18634.0 i/s - 554.13x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_or.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_OR ===
Warming up --------------------------------------
            baseline     14.323 i/s -      16.000 times in 1.117060s (69.82ms/i)
         string_bits    18.661k i/s -     19.420k times in 1.040648s (53.59μs/i)
Calculating -------------------------------------
            baseline     14.136 i/s -      42.000 times in 2.971125s (70.74ms/i)
         string_bits    18.195k i/s -     55.984k times in 3.076853s (54.96μs/i)

Comparison:
            baseline:        14.1 i/s 
         string_bits:     18195.2 i/s - 1287.15x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_or.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     30.871 i/s -      32.000 times in 1.036558s (32.39ms/i)
         string_bits    18.601k i/s -     19.250k times in 1.034897s (53.76μs/i)
Calculating -------------------------------------
            baseline     34.387 i/s -      92.000 times in 2.675448s (29.08ms/i)
         string_bits    18.383k i/s -     55.802k times in 3.035535s (54.40μs/i)

Comparison:
            baseline:        34.4 i/s 
         string_bits:     18382.9 i/s - 534.59x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_run_count.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_RUN_COUNT ===
Warming up --------------------------------------
            baseline    249.173 i/s -     250.000 times in 1.003319s (4.01ms/i)
         string_bits     1.468k i/s -      1.596k times in 1.087367s (681.31μs/i)
Calculating -------------------------------------
            baseline    277.707 i/s -     747.000 times in 2.689883s (3.60ms/i)
         string_bits     1.466k i/s -      4.403k times in 3.002424s (681.90μs/i)

Comparison:
            baseline:       277.7 i/s 
         string_bits:      1466.5 i/s - 5.28x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_run_count.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    774.069 i/s -     847.000 times in 1.094218s (1.29ms/i)
         string_bits     2.649k i/s -      2.904k times in 1.096056s (377.43μs/i)
Calculating -------------------------------------
            baseline    825.926 i/s -      2.322k times in 2.811391s (1.21ms/i)
         string_bits     2.758k i/s -      7.948k times in 2.882043s (362.61μs/i)

Comparison:
            baseline:       825.9 i/s 
         string_bits:      2757.8 i/s - 3.34x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_slice.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_SLICE ===
Warming up --------------------------------------
            baseline     80.799 i/s -      81.000 times in 1.002487s (12.38ms/i)
         string_bits     1.193k i/s -      1.309k times in 1.097309s (838.28μs/i)
Calculating -------------------------------------
            baseline     83.726 i/s -     242.000 times in 2.890385s (11.94ms/i)
         string_bits     1.125k i/s -      3.578k times in 3.181209s (889.10μs/i)

Comparison:
            baseline:        83.7 i/s 
         string_bits:      1124.7 i/s - 13.43x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_slice.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    303.307 i/s -     330.000 times in 1.088007s (3.30ms/i)
         string_bits     1.532k i/s -      1.672k times in 1.091497s (652.81μs/i)
Calculating -------------------------------------
            baseline    329.901 i/s -     909.000 times in 2.755373s (3.03ms/i)
         string_bits     1.684k i/s -      4.595k times in 2.727824s (593.65μs/i)

Comparison:
            baseline:       329.9 i/s 
         string_bits:      1684.5 i/s - 5.11x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_splice.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_SPLICE ===
Warming up --------------------------------------
            baseline     71.798 i/s -      72.000 times in 1.002807s (13.93ms/i)
         string_bits    125.433 i/s -     130.000 times in 1.036410s (7.97ms/i)
Calculating -------------------------------------
            baseline     79.545 i/s -     215.000 times in 2.702863s (12.57ms/i)
         string_bits    125.186 i/s -     376.000 times in 3.003529s (7.99ms/i)

Comparison:
            baseline:        79.5 i/s 
         string_bits:       125.2 i/s - 1.57x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_splice.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    206.206 i/s -     209.000 times in 1.013547s (4.85ms/i)
         string_bits    160.123 i/s -     165.000 times in 1.030455s (6.25ms/i)
Calculating -------------------------------------
            baseline    199.557 i/s -     618.000 times in 3.096865s (5.01ms/i)
         string_bits    177.466 i/s -     480.000 times in 2.704748s (5.63ms/i)

Comparison:
            baseline:       199.6 i/s 
         string_bits:       177.5 i/s - 1.12x  slower

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_xor.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BIT_XOR ===
Warming up --------------------------------------
            baseline     11.095 i/s -      12.000 times in 1.081611s (90.13ms/i)
         string_bits    15.142k i/s -     16.128k times in 1.065136s (66.04μs/i)
Calculating -------------------------------------
            baseline     12.229 i/s -      33.000 times in 2.698470s (81.77ms/i)
         string_bits    15.288k i/s -     45.425k times in 2.971273s (65.41μs/i)

Comparison:
            baseline:        12.2 i/s 
         string_bits:     15288.1 i/s - 1250.13x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bit_xor.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     31.137 i/s -      32.000 times in 1.027728s (32.12ms/i)
         string_bits    16.146k i/s -     17.436k times in 1.079918s (61.94μs/i)
Calculating -------------------------------------
            baseline     34.686 i/s -      93.000 times in 2.681219s (28.83ms/i)
         string_bits    15.514k i/s -     48.436k times in 3.122164s (64.46μs/i)

Comparison:
            baseline:        34.7 i/s 
         string_bits:     15513.6 i/s - 447.26x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bloom_filter.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== BLOOM_FILTER ===
Warming up --------------------------------------
            baseline      7.163 i/s -       8.000 times in 1.116859s (139.61ms/i)
         string_bits      8.437 i/s -       9.000 times in 1.066714s (118.52ms/i)
Calculating -------------------------------------
            baseline      7.993 i/s -      21.000 times in 2.627454s (125.12ms/i)
         string_bits      9.091 i/s -      25.000 times in 2.750103s (110.00ms/i)

Comparison:
            baseline:         8.0 i/s 
         string_bits:         9.1 i/s - 1.14x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/bloom_filter.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     14.352 i/s -      16.000 times in 1.114827s (69.68ms/i)
         string_bits     15.365 i/s -      16.000 times in 1.041310s (65.08ms/i)
Calculating -------------------------------------
            baseline     13.779 i/s -      43.000 times in 3.120584s (72.57ms/i)
         string_bits     15.551 i/s -      46.000 times in 2.958093s (64.31ms/i)

Comparison:
            baseline:        13.8 i/s 
         string_bits:        15.6 i/s - 1.13x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== CLEAR_BIT ===
Warming up --------------------------------------
            baseline     10.164 i/s -      12.000 times in 1.180693s (98.39ms/i)
         string_bits     18.472 i/s -      20.000 times in 1.082715s (54.14ms/i)
Calculating -------------------------------------
            baseline     10.004 i/s -      30.000 times in 2.998715s (99.96ms/i)
         string_bits     20.712 i/s -      55.000 times in 2.655406s (48.28ms/i)

Comparison:
            baseline:        10.0 i/s 
         string_bits:        20.7 i/s - 2.07x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     26.940 i/s -      30.000 times in 1.113583s (37.12ms/i)
         string_bits     33.405 i/s -      36.000 times in 1.077668s (29.94ms/i)
Calculating -------------------------------------
            baseline     22.808 i/s -      80.000 times in 3.507529s (43.84ms/i)
         string_bits     33.721 i/s -     100.000 times in 2.965549s (29.66ms/i)

Comparison:
            baseline:        22.8 i/s 
         string_bits:        33.7 i/s - 1.48x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== CLEAR_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.589 i/s -       2.000 times in 1.258502s (629.25ms/i)
         string_bits     68.786 i/s -      70.000 times in 1.017654s (14.54ms/i)
Calculating -------------------------------------
            baseline      1.482 i/s -       4.000 times in 2.699566s (674.89ms/i)
         string_bits     64.597 i/s -     206.000 times in 3.189001s (15.48ms/i)

Comparison:
            baseline:         1.5 i/s 
         string_bits:        64.6 i/s - 43.60x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/clear_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      3.452 i/s -       4.000 times in 1.158863s (289.72ms/i)
         string_bits     69.577 i/s -      70.000 times in 1.006076s (14.37ms/i)
Calculating -------------------------------------
            baseline      3.455 i/s -      10.000 times in 2.894114s (289.41ms/i)
         string_bits     77.877 i/s -     208.000 times in 2.670873s (12.84ms/i)

Comparison:
            baseline:         3.5 i/s 
         string_bits:        77.9 i/s - 22.54x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== EACH_BIT ===
Warming up --------------------------------------
            baseline     15.640 i/s -      16.000 times in 1.023035s (63.94ms/i)
         string_bits    103.566 i/s -     110.000 times in 1.062127s (9.66ms/i)
Calculating -------------------------------------
            baseline     18.120 i/s -      46.000 times in 2.538595s (55.19ms/i)
         string_bits     97.923 i/s -     310.000 times in 3.165743s (10.21ms/i)

Comparison:
            baseline:        18.1 i/s 
         string_bits:        97.9 i/s - 5.40x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     48.914 i/s -      50.000 times in 1.022202s (20.44ms/i)
         string_bits     97.927 i/s -      99.000 times in 1.010957s (10.21ms/i)
Calculating -------------------------------------
            baseline     55.030 i/s -     146.000 times in 2.653118s (18.17ms/i)
         string_bits    105.689 i/s -     293.000 times in 2.772298s (9.46ms/i)

Comparison:
            baseline:        55.0 i/s 
         string_bits:       105.7 i/s - 1.92x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit_run.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== EACH_BIT_RUN ===
Warming up --------------------------------------
            baseline     11.151 i/s -      12.000 times in 1.076148s (89.68ms/i)
         string_bits     44.575 i/s -      45.000 times in 1.009543s (22.43ms/i)
Calculating -------------------------------------
            baseline     10.930 i/s -      33.000 times in 3.019335s (91.50ms/i)
         string_bits     49.832 i/s -     133.000 times in 2.668959s (20.07ms/i)

Comparison:
            baseline:        10.9 i/s 
         string_bits:        49.8 i/s - 4.56x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/each_bit_run.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     31.936 i/s -      33.000 times in 1.033301s (31.31ms/i)
         string_bits     48.664 i/s -      54.000 times in 1.109660s (20.55ms/i)
Calculating -------------------------------------
            baseline     31.882 i/s -      95.000 times in 2.979763s (31.37ms/i)
         string_bits     50.276 i/s -     145.000 times in 2.884059s (19.89ms/i)

Comparison:
            baseline:        31.9 i/s 
         string_bits:        50.3 i/s - 1.58x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== FLIP_BIT ===
Warming up --------------------------------------
            baseline      8.726 i/s -       9.000 times in 1.031366s (114.60ms/i)
         string_bits     20.826 i/s -      21.000 times in 1.008337s (48.02ms/i)
Calculating -------------------------------------
            baseline      9.032 i/s -      26.000 times in 2.878798s (110.72ms/i)
         string_bits     20.965 i/s -      62.000 times in 2.957380s (47.70ms/i)

Comparison:
            baseline:         9.0 i/s 
         string_bits:        21.0 i/s - 2.32x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     22.767 i/s -      24.000 times in 1.054166s (43.92ms/i)
         string_bits     30.703 i/s -      32.000 times in 1.042257s (32.57ms/i)
Calculating -------------------------------------
            baseline     27.805 i/s -      68.000 times in 2.445620s (35.97ms/i)
         string_bits     35.076 i/s -      92.000 times in 2.622841s (28.51ms/i)

Comparison:
            baseline:        27.8 i/s 
         string_bits:        35.1 i/s - 1.26x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== FLIP_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.501 i/s -       2.000 times in 1.332546s (666.27ms/i)
         string_bits     66.508 i/s -      70.000 times in 1.052498s (15.04ms/i)
Calculating -------------------------------------
            baseline      1.420 i/s -       4.000 times in 2.816720s (704.18ms/i)
         string_bits     66.650 i/s -     199.000 times in 2.985728s (15.00ms/i)

Comparison:
            baseline:         1.4 i/s 
         string_bits:        66.7 i/s - 46.93x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/flip_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      4.068 i/s -       5.000 times in 1.228982s (245.80ms/i)
         string_bits     75.161 i/s -      80.000 times in 1.064386s (13.30ms/i)
Calculating -------------------------------------
            baseline      3.563 i/s -      12.000 times in 3.367714s (280.64ms/i)
         string_bits     69.308 i/s -     225.000 times in 3.246358s (14.43ms/i)

Comparison:
            baseline:         3.6 i/s 
         string_bits:        69.3 i/s - 19.45x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/hamming.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== HAMMING ===
Warming up --------------------------------------
            baseline     43.374 i/s -      45.000 times in 1.037486s (23.06ms/i)
         string_bits    938.268 i/s -     940.000 times in 1.001846s (1.07ms/i)
Calculating -------------------------------------
            baseline     43.458 i/s -     130.000 times in 2.991395s (23.01ms/i)
         string_bits    942.415 i/s -      2.814k times in 2.985945s (1.06ms/i)

Comparison:
            baseline:        43.5 i/s 
         string_bits:       942.4 i/s - 21.69x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/hamming.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    346.174 i/s -     374.000 times in 1.080381s (2.89ms/i)
         string_bits     1.057k i/s -      1.144k times in 1.082340s (946.10μs/i)
Calculating -------------------------------------
            baseline    377.444 i/s -      1.038k times in 2.750075s (2.65ms/i)
         string_bits     1.176k i/s -      3.170k times in 2.695441s (850.30μs/i)

Comparison:
            baseline:       377.4 i/s 
         string_bits:      1176.1 i/s - 3.12x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/jaccard.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== JACCARD ===
Warming up --------------------------------------
            baseline     83.990 i/s -      84.000 times in 1.000113s (11.91ms/i)
         string_bits    18.387k i/s -     19.357k times in 1.052772s (54.39μs/i)
Calculating -------------------------------------
            baseline     93.308 i/s -     251.000 times in 2.690023s (10.72ms/i)
         string_bits    19.979k i/s -     55.160k times in 2.760956s (50.05μs/i)

Comparison:
            baseline:        93.3 i/s 
         string_bits:     19978.6 i/s - 214.12x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/jaccard.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline    172.672 i/s -     180.000 times in 1.042439s (5.79ms/i)
         string_bits    20.466k i/s -     21.644k times in 1.057549s (48.86μs/i)
Calculating -------------------------------------
            baseline    181.342 i/s -     518.000 times in 2.856476s (5.51ms/i)
         string_bits    19.443k i/s -     61.398k times in 3.157865s (51.43μs/i)

Comparison:
            baseline:       181.3 i/s 
         string_bits:     19442.9 i/s - 107.22x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/rle.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== RLE ===
Warming up --------------------------------------
            baseline     10.440 i/s -      12.000 times in 1.149414s (95.78ms/i)
            each_bit     14.495 i/s -      16.000 times in 1.103827s (68.99ms/i)
        each_bit_run     43.574 i/s -      44.000 times in 1.009774s (22.95ms/i)
Calculating -------------------------------------
            baseline     10.323 i/s -      31.000 times in 3.003002s (96.87ms/i)
            each_bit     15.549 i/s -      43.000 times in 2.765381s (64.31ms/i)
        each_bit_run     44.225 i/s -     130.000 times in 2.939531s (22.61ms/i)

Comparison:
            baseline:        10.3 i/s 
            each_bit:        15.5 i/s - 1.51x  faster
        each_bit_run:        44.2 i/s - 4.28x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/rle.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     31.829 i/s -      33.000 times in 1.036796s (31.42ms/i)
            each_bit     22.287 i/s -      24.000 times in 1.076873s (44.87ms/i)
        each_bit_run     48.358 i/s -      50.000 times in 1.033944s (20.68ms/i)
Calculating -------------------------------------
            baseline     32.458 i/s -      95.000 times in 2.926837s (30.81ms/i)
            each_bit     22.820 i/s -      66.000 times in 2.892140s (43.82ms/i)
        each_bit_run     47.692 i/s -     145.000 times in 3.040358s (20.97ms/i)

Comparison:
            baseline:        32.5 i/s 
            each_bit:        22.8 i/s - 1.42x  slower
        each_bit_run:        47.7 i/s - 1.47x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT ===
Warming up --------------------------------------
            baseline      9.670 i/s -      10.000 times in 1.034160s (103.42ms/i)
         string_bits     20.772 i/s -      21.000 times in 1.010957s (48.14ms/i)
Calculating -------------------------------------
            baseline     10.838 i/s -      29.000 times in 2.675870s (92.27ms/i)
         string_bits     20.772 i/s -      62.000 times in 2.984755s (48.14ms/i)

Comparison:
            baseline:        10.8 i/s 
         string_bits:        20.8 i/s - 1.92x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     27.647 i/s -      30.000 times in 1.085096s (36.17ms/i)
         string_bits     31.098 i/s -      32.000 times in 1.029005s (32.16ms/i)
Calculating -------------------------------------
            baseline     27.215 i/s -      82.000 times in 3.013013s (36.74ms/i)
         string_bits     37.770 i/s -      93.000 times in 2.462243s (26.48ms/i)

Comparison:
            baseline:        27.2 i/s 
         string_bits:        37.8 i/s - 1.39x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_offsets.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT_OFFSETS ===
Warming up --------------------------------------
            baseline     14.079 i/s -      16.000 times in 1.136406s (71.03ms/i)
         string_bits    210.127 i/s -     228.000 times in 1.085058s (4.76ms/i)
Calculating -------------------------------------
            baseline     13.243 i/s -      42.000 times in 3.171390s (75.51ms/i)
         string_bits    236.989 i/s -     630.000 times in 2.658350s (4.22ms/i)

Comparison:
            baseline:        13.2 i/s 
         string_bits:       237.0 i/s - 17.89x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_offsets.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline     53.058 i/s -      54.000 times in 1.017746s (18.85ms/i)
         string_bits    233.140 i/s -     242.000 times in 1.038002s (4.29ms/i)
Calculating -------------------------------------
            baseline     53.097 i/s -     159.000 times in 2.994493s (18.83ms/i)
         string_bits    237.972 i/s -     699.000 times in 2.937319s (4.20ms/i)

Comparison:
            baseline:        53.1 i/s 
         string_bits:       238.0 i/s - 4.48x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_range.yaml --executables 'ruby::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby' --output faster

=== SET_BIT_RANGE ===
Warming up --------------------------------------
            baseline      1.682 i/s -       2.000 times in 1.189107s (594.55ms/i)
         string_bits     63.840 i/s -      70.000 times in 1.096495s (15.66ms/i)
Calculating -------------------------------------
            baseline      1.684 i/s -       5.000 times in 2.969512s (593.90ms/i)
         string_bits     64.280 i/s -     191.000 times in 2.971358s (15.56ms/i)

Comparison:
            baseline:         1.7 i/s 
         string_bits:        64.3 i/s - 38.18x  faster

RUBYLIB=/home/hasumi/work/string_bits/lib bundle exec benchmark-driver benchmark/set_bit_range.yaml --executables 'yjit::/home/hasumi/.rbenv/versions/4.0.4/bin/ruby --yjit' --output faster
Warming up --------------------------------------
            baseline      3.745 i/s -       4.000 times in 1.067997s (267.00ms/i)
         string_bits     72.021 i/s -      80.000 times in 1.110790s (13.88ms/i)
Calculating -------------------------------------
            baseline      3.321 i/s -      11.000 times in 3.312687s (301.15ms/i)
         string_bits     73.203 i/s -     216.000 times in 2.950683s (13.66ms/i)

Comparison:
            baseline:         3.3 i/s 
         string_bits:        73.2 i/s - 22.05x  faster

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
  string_bits: each_bit { block }                                              1967
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
