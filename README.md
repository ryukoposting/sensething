# SenseThing: Easy sensor monitoring for Linux

`sensething` is a CLI tool for discovering, reading, and logging Linux system
sensor data. Its goals are as follows:

- Make as many hardware sensors as possible visible from within a single tool,
- Provide a human-friendly way of querying specific sensors,
- Produce output in formats that are easy to parse (for humans and computers).

# Contents

1. [Rationale: why use SenseThing instead of lm-sensors?](#rationale-why-use-sensething-instead-of-lm-sensors)
2. [How SenseThing works](#how-sensething-works)
3. [Tutorial](#tutorial)
4. [Installation](#installation)
5. [Discovering your system's sensors](#discovering-your-systems-sensors)
6. [A simple way to read sensor data](#a-simple-way-to-read-sensor-data)
7. [Logging sensor data continuously](#logging-sensor-data-continuously)
   - [Units of measurement](#units-of-measurement)
   - [Changing the sampling rate](#changing-the-sampling-rate)
   - [Timestamps](#timestamps)
   - [Output formats: JSON and CSV](#output-formats-json-and-csv)
8. [Monitoring sensor data remotely](#monitoring-sensor-data-remotely)

# Rationale: why use SenseThing instead of lm-sensors?

Compared to lm-sensors, SenseThing shows all of the same sensor data, but with
some very valuable additions:

- SenseThing can report **CPU and GPU clock frequency** data, which is not
  reported by lm-sensors.
- SenseThing **supports Nvidia** GPUs, and can report many of the same
  metrics reported by nvidia-smi.

SenseThing supports CSV and JSON logging outputs, which is helpful for:

- Analyzing system thermal/frequency data when running benchmarks.
- Remotely monitoring the condition of hard-to-access systems.

# How SenseThing works

SenseThing works by traversing Linux's sysfs. It is aware of the interfaces
exposed by the hwmon, drm, and cpufreq kernel modules. Nvidia sensor data is
acquired via nvidia-smi.


# Installation

For apt-based Linux distros, SenseThing can be installed using one of the deb
files available in the [GitHub Releases].

On other distros, unfortunately you'll have to install SenseThing manually.
Run the following commands to check out this repo and install:

```sh
git clone git@github.com:ryukoposting/sensething.git
cd sensething
bundle install
rake install
sensething --version
```

[GitHub Releases]: https://github.com/ryukoposting/sensething/releases

# Discovering your system's sensors

First, you'll want to grab a list of the available sensors on your system:

```sh
# these are synonyms, use whichever one you prefer
sensething ls
sensething list-sensors
```

The `ls` (a.k.a. "list-sensors") command prints a list of sensors. Here's
a truncated example from my 10th gen ThinkPad X1:

```
acpitz/temperature_1          Temperature Sensor (hwmon1/temp1)
BAT0/voltage_0                Voltage Sensor (hwmon2/in0)
nvme/Composite                Temperature Sensor (hwmon3/temp1)
**snip**
thinkpad/fan_1                Fan (hwmon6/fan1)
thinkpad/pwm_1                PWM (hwmon6/pwm1)
thinkpad/CPU                  Temperature Sensor (hwmon6/temp1)
thinkpad/fan_2                Fan (hwmon6/fan2)
thinkpad/GPU                  Temperature Sensor (hwmon6/temp2)
thinkpad/temperature_3        Temperature Sensor (hwmon6/temp3)
thinkpad/temperature_4        Temperature Sensor (hwmon6/temp4)
**snip**
coretemp/Package id 0         Temperature Sensor (hwmon7/temp1)
coretemp/Core 0               Temperature Sensor (hwmon7/temp2)
coretemp/Core 4               Temperature Sensor (hwmon7/temp3)
coretemp/Core 8               Temperature Sensor (hwmon7/temp4)
coretemp/Core 12              Temperature Sensor (hwmon7/temp5)
coretemp/Core 16              Temperature Sensor (hwmon7/temp6)
**snip**
cpu0/frequency                CPU Frequency (cpufreq/policy0)
cpu1/frequency                CPU Frequency (cpufreq/policy1)
cpu2/frequency                CPU Frequency (cpufreq/policy2)
cpu3/frequency                CPU Frequency (cpufreq/policy3)
cpu4/frequency                CPU Frequency (cpufreq/policy4)
**snip**
card0/frequency               Graphics Frequency (drm/card0)
```

Skimming through that list, you'll see myriad temperature sensors, a couple
fans, a PWM output, battery voltage, and CPU/GPU clock frequencies.

Some of the sensors have pretty self-evident names, like `BAT0/voltage_0`
and `coretemp/Core 0`. SenseThing always tries to give descriptive,
human-friendly names to all sensors it discovers.

# A simple way to read sensor data

Let's grab a value from one of those sensors:

```sh
# 'r' is a synonym for 'read'
sensething r -s BAT0/voltage_0
sensething read -s BAT0/voltage_0
```

To read a sensor, use the `r` (a.k.a. "read") command to fetch sensor values
in a human-friendly format. Here's what I got when I ran that command:

```
BAT0/voltage_0                16490.0 mV
```

SenseThing happily prints the sensor's name, followed by its value, with its
units. Let's try adding some more sensors to our query:

```sh
sensething r -s BAT0/voltage_0 -s thinkpad/CPU -s card0/frequency
```

You can add as many sensors as you want, and SenseThing will dutifully print
out their values for you:

```
BAT0/voltage_0                16487.0 mV
thinkpad/CPU                  47.0 °C
card0/frequency               300.0 MHz
```

# Logging sensor data continuously

Let's say you're running some benchmarks, and you want to keep an eye on CPU
and GPU temperatures during the test. SenseThing's `l` (a.k.a. "log")
command is made for that purpose:

```sh
# 'l' is a synonym for 'log'
sensething l -s thinkpad/CPU -s thinkpad/GPU
sensething log -s thinkpad/CPU -s thinkpad/GPU
```

SenseThing will start printing out a CSV file containing the measurements.
Every 5 seconds, a new line of data will be printed.

```
thinkpad/CPU,thinkpad/GPU
43.0,43.0
43.0,42.0
43.0,45.0
```

## Units of measurement

To include units of measurement in the header row, add the `-u` (a.k.a
"--units") flag:

```sh
sensething l -u -s thinkpad/CPU -s thinkpad/GPU
```

The sample output above would look like this when the `-u` flag is added:

```
thinkpad/CPU [°C],thinkpad/GPU [°C]
43.0,43.0
43.0,42.0
43.0,45.0
```

## Changing the sampling rate

To make SenseThing record data every 2 seconds instead of 5, use the `-i`
(a.k.a. "--interval") flag:

```sh
sensething l -i 2
```

`-i` accepts decimal numbers like `4.2` or `0.5`, as well.

*Nvidia users: Please note that, while you can still set a faster interval,
data from nvidia-smi won't actually change faster than once per second.*

## Timestamps

Depending on your use case, it may also be useful to include timestamps
with your data. The `-t` flag (a.k.a. "--timestamp") facilitates this:

```sh
sensething l -t  # same thing as "-t seconds"
sensething l -t seconds
sensething l -t millis
```

With `-t seconds` and `-t millis`, SenseThing's timestamps will show the
time elapsed since the program started. This is usually the most useful
form when recording data during benchmarking.

When an absolute wall-clock time is desired, timestamps can also be
formatted in standard ISO 8601 standard forms:

```sh
sensething l -t iso8601           # yyyy-mm-ddThh:mm:ss+ZZZZ
sensething l -t iso8601-millis    # yyyy-mm-ddThh:mm:ss.sss+ZZZZ
```

## Output formats: JSON and CSV

SenseThing's logging feature defaults to CSV. However, it also supports
JSON output, thanks to the `-f` (a.k.a. "--format") flag:

```sh
sensething l -f json
sensething l -f csv   # this is the default
```

# Monitoring sensor data remotely

If you want to monitor a system's sensors remotely, you could simply
pipe `sensething l -f json ...` into netcat. While this approach can work
great in some scenarios, it's far from perfect.

For situations where you want a basic dashboard that shows a system's
sensor data, SenseThing's `s` command (a.k.a "serve") exposes an HTTP server
that provides a dead-simple list of the system's sensor readings:

```
# These are synonyms, use whichever one you prefer
sensething s
sensething serve
```

Run `sensething s`, open your browser, and navigate to `localhost:4567`. You'll
see a page that looks something like this:

![Screenshot of a web page titled "SenseThing Web UI," with a list of sensor measurements below the title.](/doc/webui.png)

Pretty? Not really. Informative? Absolutely!

The server's configuration can be altered using the `-a` and `-p` options,
which set the server's address and port respectively. For example,

```sh
sensething s -a 0.0.0.0 -p 80
```

Note that the HTTP server currently lacks a couple of features that will be added
eventually. However, you can trust that a simple HTML page like this one will
always be returned when you send a `GET /` with `Accept: text/html`.
