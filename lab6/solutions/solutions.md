# Step 0:

**Performance (Loop Summary & top-level table):**

**1. What is the Iteration Latency and Initiation Interval of SHIFT_LOOP?**
    - The Iteration Latency of SHIFT_LOOP is 2 cycles. 
    - The Initiation Interval of SHIFT_LOOP is 1 cycle.

**2. What is the Iteration Latency and Initiation Interval of MAC_LOOP?**
    - The Iteration Latency of MAC_LOOP is 5 cycles. 
    - The Initiation Interval of MAC_LOOP is 1 cycle.

**3. What is the total Latency (min/max) and Interval of the whole fir function?**
    - The total latency of the whole fir function is 420 nanoseconds.
    - The total Initiation Interval of the whole fir function is 43 cycles. 

**4. Why is the MAC_LOOP using only one DSP? (Hint: Refer to the HLS lecture slides on latency optimization section)**
    - The reason why the MAC_LOOP uses only one DSP is due to the fact that the for loops are not optimized for unrolling yet, which means that 
    each iteration of the loop occurs in series. Since only one iteration of the loop is occuring at once, then only 1 DSP is being used at a time.

**Operation Binding (Bind Op Report — expand MAC_LOOP):**

**5. For the MAC_LOOP, how many operations are needed? Why? For each, record: what resource it is bound to (Impl), whether a DSP is used, and what its operator latency is.**
    - For the MAC_LOOP, there are a total of 15 operations (trip count), because there are a total of 15 iterations of the loop happening. 
        - For the icmp_ln39_fu_88_p2 operation, the resource it is bound it is fabric. There is no DSP used and the operator latency is 0.
        - For the add_ln39_fu_94_p2 operation, the resource it is bound it is fabric. There is no DSP used and the operator latency is 0.
        - For the mac_muladd_16s_13ns_32s_32_4_1_U2 operation, the resource it is bound it is dsp_slice. There is one DSP used and the operator latency is 3.

**Storage Binding (Bind Storage Report):**

**6. What arrays exist in the design? For each array, record: what memory type it is bound to (e.g., BRAM, LUTRAM, FF), what port configuration is used (e.g., ram 2p/1p), and its bitwidth, depth, and number of banks.**
    - One of the arrays that exist in the design is shift_reg. It has a memory type of LUTRAM and a port configuration of ram_2p, which means a 2 port RAM. Its bitwidth is 16, depth is 15, and has one bank.
    - The second array that exists in the design is coeff. It has a memory type of LUTRAM and a port configuration of rom_1p, which means a 1 port ROM. Its bitwidth is 13, depth is 15, and has one bank. 
    
**7. What is the total resource usage of the whole fir function (DSP, LUT, FF, BRAM)?**
    - The total DSP usage for the whole fir function is 1 DSP, 375 LUTs, 213 FFs, and no BRAM usage.

## Step 1:

**1. Does SHIFT_LOOP still appear in the Loop Summary?**
    - No SHIFT_LOOP does not appear in the Loop Summary, since all of the iterations are being done at once, so it is not really a loop anymore.

**2. What is the total Latency (min/max) and Interval of the whole fir function after optimization?**
    - The total Latency of the whole fir function is 370 nanoseconds.
    - The total Initiation Interval of the whole fir function is 38 cycles. 

**3. Compare it to the baseline latency from Step 0. Did it decrease by ~14 cycles (the original SHIFT_LOOP latency)?**
    - No, the total Latency only decreased by 5 cycles (50 nanoseconds).

**4. You may notice that the function latency barely changed, even though you unrolled the loop. Why? (Hint: Look at the Bind Storage Report)**
    - The total Latency of the function barely changed, because the data dependency is still not gone, since the memory type is still a ram_t2p configuration and the fact that unrolling a loop does not automatically remove dependencies. 

**5. Find a way to eliminate the remaining latency from SHIFT_LOOP. (Hint: Figure what pragma to add based on the previous step's answer)**
    - Added "#pragma HLS ARRAY_PARTITION variable=shift_reg complete dim=1"

**6. What is the total Latency (min/max) and Interval of the whole fir function after optimization? How much did it reduce compared to baseline?**
    - The total Latency of the whole fir function is 230 nanoseconds.
    - The total Initiation Interval of the whole fir function is 24 cycles. 

**7. What is the total resource usage of the whole fir function (DSP, LUT, FF, BRAM)? What is the biggest change and why?**
    - DSP: 1
    - LUT: 298
    - FF: 663
    - BRAM: 0
    - The biggest change is in the FF count, because the ARRAY_PARTITION pragma essentially splits large arrays into smaller arrays or individual registers (FFs) causing an increase in them.

## Step 2:

**1. Does MAC_LOOP still appear in the Loop Summary?**
    - No MAC_LOOP does not appear in the Loop Summary, since all of the iterations are being done at once, so it is not really a loop anymore.

**2. What is the total Latency (min/max) and Interval of the whole fir function after optimization? How much did it reduce compared to previous step?**
    - The total Latency of the whole fir function is 60 nanoseconds.
    - The total Initiation Interval of the whole fir function is 7 cycles. 

**3. What is the total resource usage of the whole fir function (DSP, LUT, FF, BRAM)? What is the biggest change and why?**
    - DSP: 8
    - LUT: 225
    - FF: 455
    - BRAM: 0
    - The biggest change is in the DSP count, because the fact that there are MACs happening in parallel means that multiple DSPs need to be utilized to allow the parallelization to occur.

**4. For full unrolling, we expect 15 MACs to be instantiated. Does the report show this? If not, why?**
    - No the report does not explicitly report 15 MACs being instantiated, because the HLS decided that 15 different DSPs would be overkill and even with the unrolling of both loops, there is only partial parallelization happening and the HLS schedules operations over time.

**5. Why is the function Initiation Interval still greater than 1? (Hint: Refer to the HLS lecture slides on throughput optimization section)**
    - The function Initiation Interval is still greater than 1, because the fir filter code is not fully pipelined yet.

## Step 3:

**1. What is iteration Interval of the whole fir function after optimization?**
    - The total Initiation Interval of the whole fir function is 1 cycle, because the fir filter code is pipelined. 

**2. What is the total resource usage of the whole fir function (DSP, LUT, FF, BRAM)? What is the biggest change and why?**
    - DSP: 8
    - LUT: 377
    - FF: 869
    - BRAM: 0
    - The biggest change is in the FF count, because pipelining and the pragmas added results in data dependencies to be resolved, which resulted in an increase in the number of individual registers (FFs) needed to store each and every value for it to be ready to use.

**3. What is the iteration Interval now? Is it still 1? If so why? (Hint: Refer to the HLS lecture slides on throughput optimization section)**
    - The total Initiation Interval of the whole fir function is still 1 cycle, because the PIPELINE II pragma is still executing in the code that allows for bottlenecks to be removed so the pipeline can run at full throughput.

**4-5. Use the ALLOCATION pragma to limit the number of DSPs used to 2. Run synthesis. What is your expected II for the fir function? What is the actual II in the synthesis report?**
    - The expected Initiation Interval with 2 DSPs would result in the same number of DSPs from Step 2, which was 7 cycles. The actial Initiation Interval with 2 DSPs was found to be 7 cycles indeed. This is due to the fact that applying a limitation on the number of DSPs essentially limits to amount of parallel MACs that can occur, which slows down the entire FIR process.

## Step 4:

    - Completed Step 4 and got the resulting export.zip folder.
