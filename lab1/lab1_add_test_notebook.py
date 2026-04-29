#!/usr/bin/env python
# coding: utf-8

# In[1]:


from pynq import Overlay


# In[2]:


ol = Overlay("/home/xilinx/overlays/lab1_overlay.bit")


# In[5]:


help(ol)


# In[28]:


io = {
    "a": ol.axi_gpio_1.channel1,
    "b": ol.axi_gpio_1.channel2,
    "sum": ol.axi_gpio_0.channel1
}


# In[52]:


# singel adder test
io["a"].write(2, 0xFFFF)
io["b"].write(8, 0xFFFF)

# Should print 10 (8 + 2)
io["sum"].read()


# In[47]:


# Test function
import random
def test_adder(iterations=1000):
    passed = 0
    failed = 0

    for i in range(iterations):
        # Generate random 16-bit values
        a = random.randint(0, 0xFFFF)
        b = random.randint(0, 0xFFFF)

        # Write to GPIO
        io["a"].write(a, 0xFFFF)
        io["b"].write(b, 0xFFFF)

        # Read sum (17-bit)
        sum_read = io["sum"].read()

        # Calculate expected 17-bit sum
        expected_sum = (a + b) & 0x1FFFF

        # Check
        if sum_read == expected_sum:
            passed += 1
        else:
            failed += 1
            print(f"Failed at iteration {i}: a={a}, b={b}, expected={expected_sum}, got={sum_read}")

    print(f"Test completed: {passed} passed, {failed} failed")


# In[49]:


test_adder(1000)

