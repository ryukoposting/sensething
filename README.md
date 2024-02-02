# SenseThing: A sensor tool for Linux

`sensething` is a CLI tool that aims to:

- Make as many sensors as possible visible from within a single tool,
- Provide a human-friendly way of querying specific sensors,
- Deliver output in formats that are easy to parse (for humans and computers),
- Be as simple to use as possible.

`sensething` provides access to all the same sensors as `lm-sensors`, but it
also includes sensor data from Nvidia graphics cards, as well as CPU clock
frequencies. It will provide access to even more sensors in the future.
