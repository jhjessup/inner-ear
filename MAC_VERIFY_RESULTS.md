# Mac Verification Results — TOOLCHAIN REPAIR FAILED

- **Branch:** `chore/mac-verify-scaffold`
- **Commit:** `e4ff36712ed00671608706a79649d08852cba811`
- **Timestamp (UTC):** 2026-08-27T18:44:16Z

swift build/test were not attempted — the toolchain itself is broken.
See repair log below.

```
Detected known CLT/manifest-link toolchain issue. Attempting automatic fixes.

--- Attempt 1: install/switch to an official Swift.org toolchain via swiftly (no sudo) ---
installer: Package name is 
installer: Installing at base path /Users/jhjessup
installer: The install was successful.
Creating shell environment file for the user...
Updating profile...
Fetching the latest stable Swift release...
Installing Swift 6.3.3
Downloading Swift 6.3.3
0%: Downloaded 2.3 MiB of 1433.9 MiB
0%: Downloaded 9.3 MiB of 1433.9 MiB
0%: Downloaded 13.1 MiB of 1433.9 MiB
1%: Downloaded 20.2 MiB of 1433.9 MiB
1%: Downloaded 26.0 MiB of 1433.9 MiB
2%: Downloaded 31.5 MiB of 1433.9 MiB
2%: Downloaded 36.4 MiB of 1433.9 MiB
2%: Downloaded 40.9 MiB of 1433.9 MiB
3%: Downloaded 44.6 MiB of 1433.9 MiB
3%: Downloaded 47.4 MiB of 1433.9 MiB
3%: Downloaded 50.4 MiB of 1433.9 MiB
3%: Downloaded 53.8 MiB of 1433.9 MiB
4%: Downloaded 57.6 MiB of 1433.9 MiB
4%: Downloaded 62.0 MiB of 1433.9 MiB
4%: Downloaded 66.7 MiB of 1433.9 MiB
5%: Downloaded 72.5 MiB of 1433.9 MiB
5%: Downloaded 79.8 MiB of 1433.9 MiB
5%: Downloaded 85.0 MiB of 1433.9 MiB
5%: Downloaded 85.4 MiB of 1433.9 MiB
6%: Downloaded 87.2 MiB of 1433.9 MiB
6%: Downloaded 89.7 MiB of 1433.9 MiB
6%: Downloaded 92.2 MiB of 1433.9 MiB
6%: Downloaded 94.0 MiB of 1433.9 MiB
6%: Downloaded 96.8 MiB of 1433.9 MiB
7%: Downloaded 102.2 MiB of 1433.9 MiB
7%: Downloaded 109.4 MiB of 1433.9 MiB
8%: Downloaded 115.1 MiB of 1433.9 MiB
8%: Downloaded 118.9 MiB of 1433.9 MiB
8%: Downloaded 122.0 MiB of 1433.9 MiB
8%: Downloaded 125.7 MiB of 1433.9 MiB
9%: Downloaded 129.2 MiB of 1433.9 MiB
9%: Downloaded 133.2 MiB of 1433.9 MiB
9%: Downloaded 138.7 MiB of 1433.9 MiB
10%: Downloaded 146.3 MiB of 1433.9 MiB
10%: Downloaded 153.5 MiB of 1433.9 MiB
11%: Downloaded 160.5 MiB of 1433.9 MiB
11%: Downloaded 166.0 MiB of 1433.9 MiB
11%: Downloaded 170.8 MiB of 1433.9 MiB
12%: Downloaded 175.9 MiB of 1433.9 MiB
12%: Downloaded 181.0 MiB of 1433.9 MiB
12%: Downloaded 186.1 MiB of 1433.9 MiB
13%: Downloaded 191.7 MiB of 1433.9 MiB
13%: Downloaded 199.3 MiB of 1433.9 MiB
14%: Downloaded 206.8 MiB of 1433.9 MiB
14%: Downloaded 213.8 MiB of 1433.9 MiB
15%: Downloaded 218.9 MiB of 1433.9 MiB
15%: Downloaded 223.5 MiB of 1433.9 MiB
15%: Downloaded 227.2 MiB of 1433.9 MiB
16%: Downloaded 229.7 MiB of 1433.9 MiB
16%: Downloaded 230.8 MiB of 1433.9 MiB
16%: Downloaded 231.9 MiB of 1433.9 MiB
16%: Downloaded 234.8 MiB of 1433.9 MiB
16%: Downloaded 237.4 MiB of 1433.9 MiB
16%: Downloaded 240.9 MiB of 1433.9 MiB
17%: Downloaded 245.5 MiB of 1433.9 MiB
17%: Downloaded 251.0 MiB of 1433.9 MiB
18%: Downloaded 258.7 MiB of 1433.9 MiB
18%: Downloaded 265.7 MiB of 1433.9 MiB
18%: Downloaded 271.4 MiB of 1433.9 MiB
19%: Downloaded 276.5 MiB of 1433.9 MiB
19%: Downloaded 282.0 MiB of 1433.9 MiB
20%: Downloaded 287.1 MiB of 1433.9 MiB
20%: Downloaded 292.2 MiB of 1433.9 MiB
20%: Downloaded 297.3 MiB of 1433.9 MiB
21%: Downloaded 302.4 MiB of 1433.9 MiB
21%: Downloaded 309.9 MiB of 1433.9 MiB
21%: Downloaded 314.1 MiB of 1433.9 MiB
22%: Downloaded 318.4 MiB of 1433.9 MiB
22%: Downloaded 322.7 MiB of 1433.9 MiB
22%: Downloaded 327.2 MiB of 1433.9 MiB
23%: Downloaded 331.6 MiB of 1433.9 MiB
23%: Downloaded 337.6 MiB of 1433.9 MiB
24%: Downloaded 344.9 MiB of 1433.9 MiB
24%: Downloaded 351.8 MiB of 1433.9 MiB
24%: Downloaded 357.7 MiB of 1433.9 MiB
25%: Downloaded 359.3 MiB of 1433.9 MiB
25%: Downloaded 360.6 MiB of 1433.9 MiB
25%: Downloaded 361.2 MiB of 1433.9 MiB
25%: Downloaded 362.8 MiB of 1433.9 MiB
25%: Downloaded 364.0 MiB of 1433.9 MiB
25%: Downloaded 367.9 MiB of 1433.9 MiB
25%: Downloaded 370.6 MiB of 1433.9 MiB
26%: Downloaded 372.9 MiB of 1433.9 MiB
26%: Downloaded 377.9 MiB of 1433.9 MiB
26%: Downloaded 382.7 MiB of 1433.9 MiB
27%: Downloaded 387.7 MiB of 1433.9 MiB
27%: Downloaded 393.9 MiB of 1433.9 MiB
27%: Downloaded 399.4 MiB of 1433.9 MiB
28%: Downloaded 405.3 MiB of 1433.9 MiB
28%: Downloaded 412.0 MiB of 1433.9 MiB
29%: Downloaded 419.3 MiB of 1433.9 MiB
29%: Downloaded 426.5 MiB of 1433.9 MiB
30%: Downloaded 433.4 MiB of 1433.9 MiB
30%: Downloaded 440.4 MiB of 1433.9 MiB
31%: Downloaded 444.6 MiB of 1433.9 MiB
31%: Downloaded 444.8 MiB of 1433.9 MiB
31%: Downloaded 445.8 MiB of 1433.9 MiB
31%: Downloaded 446.3 MiB of 1433.9 MiB
31%: Downloaded 446.8 MiB of 1433.9 MiB
31%: Downloaded 447.6 MiB of 1433.9 MiB
31%: Downloaded 449.4 MiB of 1433.9 MiB
31%: Downloaded 452.8 MiB of 1433.9 MiB
31%: Downloaded 458.0 MiB of 1433.9 MiB
32%: Downloaded 463.1 MiB of 1433.9 MiB
32%: Downloaded 469.5 MiB of 1433.9 MiB
33%: Downloaded 473.9 MiB of 1433.9 MiB
33%: Downloaded 477.0 MiB of 1433.9 MiB
33%: Downloaded 480.4 MiB of 1433.9 MiB
33%: Downloaded 484.1 MiB of 1433.9 MiB
33%: Downloaded 487.5 MiB of 1433.9 MiB
34%: Downloaded 492.7 MiB of 1433.9 MiB
34%: Downloaded 496.5 MiB of 1433.9 MiB
34%: Downloaded 496.7 MiB of 1433.9 MiB
34%: Downloaded 496.8 MiB of 1433.9 MiB
34%: Downloaded 498.2 MiB of 1433.9 MiB
34%: Downloaded 498.6 MiB of 1433.9 MiB
34%: Downloaded 499.5 MiB of 1433.9 MiB
35%: Downloaded 501.9 MiB of 1433.9 MiB
35%: Downloaded 506.7 MiB of 1433.9 MiB
35%: Downloaded 513.6 MiB of 1433.9 MiB
36%: Downloaded 519.9 MiB of 1433.9 MiB
36%: Downloaded 523.1 MiB of 1433.9 MiB
36%: Downloaded 526.9 MiB of 1433.9 MiB
37%: Downloaded 530.7 MiB of 1433.9 MiB
37%: Downloaded 534.5 MiB of 1433.9 MiB
37%: Downloaded 538.6 MiB of 1433.9 MiB
37%: Downloaded 544.2 MiB of 1433.9 MiB
38%: Downloaded 551.5 MiB of 1433.9 MiB
38%: Downloaded 557.6 MiB of 1433.9 MiB
39%: Downloaded 563.4 MiB of 1433.9 MiB
39%: Downloaded 567.8 MiB of 1433.9 MiB
39%: Downloaded 571.1 MiB of 1433.9 MiB
40%: Downloaded 576.1 MiB of 1433.9 MiB
40%: Downloaded 581.2 MiB of 1433.9 MiB
40%: Downloaded 586.5 MiB of 1433.9 MiB
41%: Downloaded 592.7 MiB of 1433.9 MiB
41%: Downloaded 600.0 MiB of 1433.9 MiB
42%: Downloaded 605.6 MiB of 1433.9 MiB
42%: Downloaded 610.8 MiB of 1433.9 MiB
43%: Downloaded 616.7 MiB of 1433.9 MiB
43%: Downloaded 621.4 MiB of 1433.9 MiB
43%: Downloaded 626.8 MiB of 1433.9 MiB
44%: Downloaded 631.4 MiB of 1433.9 MiB
44%: Downloaded 634.4 MiB of 1433.9 MiB
44%: Downloaded 636.7 MiB of 1433.9 MiB
44%: Downloaded 641.1 MiB of 1433.9 MiB
45%: Downloaded 646.0 MiB of 1433.9 MiB
45%: Downloaded 650.4 MiB of 1433.9 MiB
45%: Downloaded 654.7 MiB of 1433.9 MiB
45%: Downloaded 658.0 MiB of 1433.9 MiB
46%: Downloaded 661.9 MiB of 1433.9 MiB
46%: Downloaded 666.0 MiB of 1433.9 MiB
46%: Downloaded 670.2 MiB of 1433.9 MiB
47%: Downloaded 674.8 MiB of 1433.9 MiB
47%: Downloaded 679.5 MiB of 1433.9 MiB
47%: Downloaded 685.8 MiB of 1433.9 MiB
48%: Downloaded 693.5 MiB of 1433.9 MiB
48%: Downloaded 696.1 MiB of 1433.9 MiB
48%: Downloaded 700.5 MiB of 1433.9 MiB
49%: Downloaded 703.7 MiB of 1433.9 MiB
49%: Downloaded 708.0 MiB of 1433.9 MiB
49%: Downloaded 711.8 MiB of 1433.9 MiB
49%: Downloaded 716.1 MiB of 1433.9 MiB
50%: Downloaded 721.0 MiB of 1433.9 MiB
50%: Downloaded 726.7 MiB of 1433.9 MiB
50%: Downloaded 731.3 MiB of 1433.9 MiB
51%: Downloaded 735.4 MiB of 1433.9 MiB
51%: Downloaded 740.2 MiB of 1433.9 MiB
51%: Downloaded 744.6 MiB of 1433.9 MiB
52%: Downloaded 749.8 MiB of 1433.9 MiB
52%: Downloaded 754.4 MiB of 1433.9 MiB
53%: Downloaded 760.3 MiB of 1433.9 MiB
53%: Downloaded 763.7 MiB of 1433.9 MiB
53%: Downloaded 766.9 MiB of 1433.9 MiB
53%: Downloaded 769.5 MiB of 1433.9 MiB
53%: Downloaded 772.7 MiB of 1433.9 MiB
54%: Downloaded 776.9 MiB of 1433.9 MiB
54%: Downloaded 781.3 MiB of 1433.9 MiB
54%: Downloaded 785.9 MiB of 1433.9 MiB
55%: Downloaded 790.5 MiB of 1433.9 MiB
55%: Downloaded 795.3 MiB of 1433.9 MiB
55%: Downloaded 800.8 MiB of 1433.9 MiB
56%: Downloaded 807.4 MiB of 1433.9 MiB
56%: Downloaded 812.7 MiB of 1433.9 MiB
57%: Downloaded 817.5 MiB of 1433.9 MiB
57%: Downloaded 821.8 MiB of 1433.9 MiB
57%: Downloaded 826.7 MiB of 1433.9 MiB
58%: Downloaded 831.7 MiB of 1433.9 MiB
58%: Downloaded 837.4 MiB of 1433.9 MiB
58%: Downloaded 844.6 MiB of 1433.9 MiB
59%: Downloaded 851.7 MiB of 1433.9 MiB
59%: Downloaded 857.4 MiB of 1433.9 MiB
60%: Downloaded 863.0 MiB of 1433.9 MiB
60%: Downloaded 869.2 MiB of 1433.9 MiB
60%: Downloaded 873.7 MiB of 1433.9 MiB
61%: Downloaded 879.2 MiB of 1433.9 MiB
61%: Downloaded 886.1 MiB of 1433.9 MiB
62%: Downloaded 893.1 MiB of 1433.9 MiB
62%: Downloaded 895.6 MiB of 1433.9 MiB
62%: Downloaded 896.1 MiB of 1433.9 MiB
62%: Downloaded 896.9 MiB of 1433.9 MiB
62%: Downloaded 898.4 MiB of 1433.9 MiB
62%: Downloaded 902.1 MiB of 1433.9 MiB
63%: Downloaded 908.4 MiB of 1433.9 MiB
63%: Downloaded 911.1 MiB of 1433.9 MiB
63%: Downloaded 914.0 MiB of 1433.9 MiB
63%: Downloaded 917.6 MiB of 1433.9 MiB
64%: Downloaded 920.0 MiB of 1433.9 MiB
64%: Downloaded 923.7 MiB of 1433.9 MiB
64%: Downloaded 928.4 MiB of 1433.9 MiB
65%: Downloaded 933.3 MiB of 1433.9 MiB
65%: Downloaded 938.5 MiB of 1433.9 MiB
65%: Downloaded 944.9 MiB of 1433.9 MiB
66%: Downloaded 952.5 MiB of 1433.9 MiB
66%: Downloaded 959.3 MiB of 1433.9 MiB
67%: Downloaded 962.8 MiB of 1433.9 MiB
67%: Downloaded 965.8 MiB of 1433.9 MiB
67%: Downloaded 969.0 MiB of 1433.9 MiB
67%: Downloaded 971.9 MiB of 1433.9 MiB
68%: Downloaded 975.5 MiB of 1433.9 MiB
68%: Downloaded 980.3 MiB of 1433.9 MiB
68%: Downloaded 987.5 MiB of 1433.9 MiB
69%: Downloaded 991.9 MiB of 1433.9 MiB
69%: Downloaded 997.2 MiB of 1433.9 MiB
69%: Downloaded 1002.2 MiB of 1433.9 MiB
69%: Downloaded 1002.5 MiB of 1433.9 MiB
69%: Downloaded 1002.9 MiB of 1433.9 MiB
70%: Downloaded 1004.1 MiB of 1433.9 MiB
70%: Downloaded 1007.2 MiB of 1433.9 MiB
70%: Downloaded 1012.1 MiB of 1433.9 MiB
70%: Downloaded 1018.0 MiB of 1433.9 MiB
71%: Downloaded 1025.6 MiB of 1433.9 MiB
71%: Downloaded 1031.4 MiB of 1433.9 MiB
72%: Downloaded 1036.8 MiB of 1433.9 MiB
72%: Downloaded 1040.8 MiB of 1433.9 MiB
72%: Downloaded 1044.7 MiB of 1433.9 MiB
73%: Downloaded 1049.2 MiB of 1433.9 MiB
73%: Downloaded 1053.8 MiB of 1433.9 MiB
73%: Downloaded 1058.7 MiB of 1433.9 MiB
74%: Downloaded 1065.0 MiB of 1433.9 MiB
74%: Downloaded 1070.3 MiB of 1433.9 MiB
75%: Downloaded 1076.1 MiB of 1433.9 MiB
75%: Downloaded 1079.1 MiB of 1433.9 MiB
75%: Downloaded 1084.6 MiB of 1433.9 MiB
75%: Downloaded 1089.0 MiB of 1433.9 MiB
76%: Downloaded 1093.3 MiB of 1433.9 MiB
76%: Downloaded 1098.4 MiB of 1433.9 MiB
76%: Downloaded 1103.5 MiB of 1433.9 MiB
77%: Downloaded 1108.5 MiB of 1433.9 MiB
77%: Downloaded 1115.6 MiB of 1433.9 MiB
78%: Downloaded 1122.7 MiB of 1433.9 MiB
78%: Downloaded 1124.8 MiB of 1433.9 MiB
78%: Downloaded 1127.7 MiB of 1433.9 MiB
78%: Downloaded 1128.6 MiB of 1433.9 MiB
78%: Downloaded 1129.2 MiB of 1433.9 MiB
78%: Downloaded 1130.0 MiB of 1433.9 MiB
78%: Downloaded 1132.6 MiB of 1433.9 MiB
79%: Downloaded 1137.2 MiB of 1433.9 MiB
79%: Downloaded 1144.4 MiB of 1433.9 MiB
79%: Downloaded 1144.9 MiB of 1433.9 MiB
79%: Downloaded 1144.9 MiB of 1433.9 MiB
79%: Downloaded 1145.8 MiB of 1433.9 MiB
79%: Downloaded 1146.0 MiB of 1433.9 MiB
79%: Downloaded 1146.0 MiB of 1433.9 MiB
79%: Downloaded 1146.0 MiB of 1433.9 MiB
79%: Downloaded 1146.3 MiB of 1433.9 MiB
80%: Downloaded 1150.7 MiB of 1433.9 MiB
80%: Downloaded 1155.8 MiB of 1433.9 MiB
80%: Downloaded 1157.5 MiB of 1433.9 MiB
80%: Downloaded 1157.6 MiB of 1433.9 MiB
80%: Downloaded 1158.3 MiB of 1433.9 MiB
80%: Downloaded 1160.5 MiB of 1433.9 MiB
81%: Downloaded 1165.1 MiB of 1433.9 MiB
81%: Downloaded 1171.3 MiB of 1433.9 MiB
81%: Downloaded 1172.7 MiB of 1433.9 MiB
81%: Downloaded 1174.3 MiB of 1433.9 MiB
82%: Downloaded 1175.9 MiB of 1433.9 MiB
82%: Downloaded 1178.6 MiB of 1433.9 MiB
82%: Downloaded 1183.0 MiB of 1433.9 MiB
82%: Downloaded 1188.7 MiB of 1433.9 MiB
83%: Downloaded 1195.5 MiB of 1433.9 MiB
83%: Downloaded 1198.2 MiB of 1433.9 MiB
83%: Downloaded 1199.7 MiB of 1433.9 MiB
83%: Downloaded 1200.1 MiB of 1433.9 MiB
83%: Downloaded 1201.6 MiB of 1433.9 MiB
84%: Downloaded 1205.1 MiB of 1433.9 MiB
84%: Downloaded 1210.0 MiB of 1433.9 MiB
84%: Downloaded 1215.3 MiB of 1433.9 MiB
85%: Downloaded 1221.0 MiB of 1433.9 MiB
85%: Downloaded 1227.0 MiB of 1433.9 MiB
85%: Downloaded 1232.1 MiB of 1433.9 MiB
86%: Downloaded 1238.6 MiB of 1433.9 MiB
86%: Downloaded 1242.7 MiB of 1433.9 MiB
87%: Downloaded 1248.7 MiB of 1433.9 MiB
87%: Downloaded 1255.2 MiB of 1433.9 MiB
88%: Downloaded 1262.4 MiB of 1433.9 MiB
88%: Downloaded 1266.4 MiB of 1433.9 MiB
88%: Downloaded 1270.0 MiB of 1433.9 MiB
88%: Downloaded 1270.3 MiB of 1433.9 MiB
88%: Downloaded 1270.7 MiB of 1433.9 MiB
88%: Downloaded 1271.9 MiB of 1433.9 MiB
88%: Downloaded 1273.7 MiB of 1433.9 MiB
89%: Downloaded 1276.5 MiB of 1433.9 MiB
89%: Downloaded 1280.2 MiB of 1433.9 MiB
89%: Downloaded 1285.7 MiB of 1433.9 MiB
90%: Downloaded 1291.1 MiB of 1433.9 MiB
90%: Downloaded 1297.0 MiB of 1433.9 MiB
90%: Downloaded 1303.1 MiB of 1433.9 MiB
91%: Downloaded 1309.6 MiB of 1433.9 MiB
91%: Downloaded 1316.5 MiB of 1433.9 MiB
92%: Downloaded 1323.4 MiB of 1433.9 MiB
92%: Downloaded 1329.1 MiB of 1433.9 MiB
93%: Downloaded 1334.6 MiB of 1433.9 MiB
93%: Downloaded 1338.9 MiB of 1433.9 MiB
93%: Downloaded 1340.7 MiB of 1433.9 MiB
93%: Downloaded 1344.9 MiB of 1433.9 MiB
94%: Downloaded 1350.1 MiB of 1433.9 MiB
94%: Downloaded 1355.2 MiB of 1433.9 MiB
94%: Downloaded 1361.4 MiB of 1433.9 MiB
95%: Downloaded 1368.6 MiB of 1433.9 MiB
95%: Downloaded 1375.6 MiB of 1433.9 MiB
96%: Downloaded 1379.2 MiB of 1433.9 MiB
96%: Downloaded 1385.1 MiB of 1433.9 MiB
96%: Downloaded 1390.3 MiB of 1433.9 MiB
97%: Downloaded 1396.4 MiB of 1433.9 MiB
97%: Downloaded 1402.2 MiB of 1433.9 MiB
98%: Downloaded 1408.9 MiB of 1433.9 MiB
98%: Downloaded 1413.8 MiB of 1433.9 MiB
98%: Downloaded 1416.8 MiB of 1433.9 MiB
99%: Downloaded 1419.9 MiB of 1433.9 MiB
99%: Downloaded 1423.1 MiB of 1433.9 MiB
99%: Downloaded 1426.5 MiB of 1433.9 MiB
99%: Downloaded 1430.3 MiB of 1433.9 MiB
100%: Downloaded 1433.9 MiB of 1433.9 MiB
Installing package in user home directory...
The file `/Users/jhjessup/tmp/inner-ear/.swift-version` has been set to `Swift 6.3.3`
The global default toolchain has been set to `Swift 6.3.3`
Swift 6.3.3 is installed successfully!
Fetching the latest stable Swift release...
Swift 6.3.3 is already installed
The file `/Users/jhjessup/tmp/inner-ear/.swift-version` has been set to `Swift 6.3.3` (was 6.3.3)

--- Attempt 2: reinstall Command Line Tools (needs sudo; best effort) ---
Passwordless sudo not available — cannot automate the CLT reinstall
(needs your password and a GUI 'Install' click). Run manually:
  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install

Automatic fixes did not resolve the toolchain issue. Last probe log:
[0/1] Planning build
Building for debugging...
[0/6] Write swift-version-29206828342AA87C.txt
[2/18] Compiling InnerEarCore Recording.swift
[3/18] Compiling InnerEarCore TranscriptSegment.swift
[4/18] Compiling InnerEarCore ExportService.swift
[5/18] Compiling InnerEarCore Summary.swift
[6/18] Compiling InnerEarCore Speaker.swift
[7/18] Compiling InnerEarCore RecordingViewModel.swift
[8/18] Compiling InnerEarCore TranscriptionService.swift
[9/18] Compiling InnerEarCore Transcript.swift
[10/18] Emitting module InnerEarCore
[11/18] Compiling InnerEarCore SummarizationService.swift
[12/18] Compiling InnerEarCore DiarizationService.swift
[13/18] Compiling InnerEarCore AudioCaptureService.swift
[14/19] Compiling InnerEarCore RecordingView.swift
[15/26] Compiling InnerEarCLI CLI.swift
[16/26] Emitting module InnerEarCLI
[17/26] Compiling InnerEarCLI main.swift
[17/26] Write Objects.LinkFileList
[19/26] Compiling InnerEarCoreTests Fakes.swift
[20/26] Compiling InnerEarCoreTests RecordingViewModelTests.swift
[21/26] Emitting module InnerEarCoreTests
[22/26] Compiling InnerEarCoreTests ServiceContractTests.swift
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:28:24: error: cannot find 'Date' in scope
26 |         let recording = Recording(
27 |             title: "r",
28 |             createdAt: Date(timeIntervalSince1970: 0),
   |                        `- error: cannot find 'Date' in scope
29 |             duration: 1,
30 |             microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")

/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:30:32: error: cannot find 'URL' in scope
28 |             createdAt: Date(timeIntervalSince1970: 0),
29 |             duration: 1,
30 |             microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")
   |                                `- error: cannot find 'URL' in scope
31 |         )
32 | 

/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:47:24: error: cannot find 'Date' in scope
45 |         let recording = Recording(
46 |             title: "r",
47 |             createdAt: Date(timeIntervalSince1970: 0),
   |                        `- error: cannot find 'Date' in scope
48 |             duration: 1,
49 |             microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")

/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:49:32: error: cannot find 'URL' in scope
47 |             createdAt: Date(timeIntervalSince1970: 0),
48 |             duration: 1,
49 |             microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")
   |                                `- error: cannot find 'URL' in scope
50 |         )
51 | 

/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:72:27: error: cannot find 'URL' in scope
70 |         let service = FakeExportService()
71 |         let transcript = TestFixtures.transcript()
72 |         let destination = URL(fileURLWithPath: "/tmp/export.md")
   |                           `- error: cannot find 'URL' in scope
73 | 
74 |         let resultURL = try await service.export(transcript: transcript, summary: nil, format: .markdown, to: destination)
[22/26] Linking innerear
error: fatalError
```
