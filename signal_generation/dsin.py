import math
import matplotlib.pyplot as plt
from numpy import savetxt

sig = [0] * 32
t = range(0,32)

for i in t:
    sig[i] = round(2048 + 2048*math.sin(i*2*math.pi/32))

savetxt('dsin32', sig, fmt='%i', delimiter=',')

# plt.plot(t, sig)
# plt.show()
# print(sig)
