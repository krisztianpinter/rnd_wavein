rnd_wavein
==========

small windows tool for creating random data from sound card noise


before you start
================

caveat 1, entropy
-----------------

generating random is no joke. if there was a one size fits all solution, you
would have it already on your system. sources of randomness are unreliable.
before you use this program, you need to get information about your recording
devices. you need to assess the entropy production. failing this might render
the data predictable for any attacker.

i recommend recording a chunk of raw data, and analysing it with various
tools. among others:

1. try compressing into lossless audio format, like FLAC
2. try compressing with a regular LZW compressor, like 7zip
3. use any entropy calculator on the data
 
from these data, try to establish the entropy content in bits per sample.
for example if you can compress it down to 10%, it means a maximum of
0.1bit/bit = 1.6bit/sample entropy content. be conservative, be on the
safe side.


caveat 2, secrecy
-----------------

in many cases, you want your random data to be secret. this generator uses
solely the sound card noise. therefore any attacker listening on on your
sound card can acquire the same entropy, and recreate your random. make sure
that malicious programs are not running on the system, not even in user mode.


command line options
====================

<b>rnd_wavein</b> &lt;size&gt; &lt;output&gt; [-R] [-S&lt;samples&gt;] [-B&lt;block&gt;] -D&lt;device&gt;

&lt;output&gt; is either filename or * for stdout.

&lt;size&gt; is the demanded amount of data in kilobytes.

-R writes unwhitened raw data. -S and -B ignored.

-S sets the number of samples to absorb before squeezing a block.
   default is 256
   
-B sets the amount of data squeezed at a time, in bytes. default is 168.

-D sets the recording device. &lt;device&gt; can be either #number or device name.
   #number goes from 0 to the number of available recording devices minus one.
   if omitted, the default device is used.

notes on parameters
-------------------

you should specify a parameter for S to have at least 128 bit entropy. if you
estimate your entropy to be at least 0.5 bit per sample, specify -S256.

the -B parameter can determines the speed but also the recovery time from a
compromised internal state. the data production rate can be calculated with:

rate = 88200/S*B byte/s

the actual measured rate can be a little bit lower, if the system is bottle-
necked by something else than the recording for periods.
