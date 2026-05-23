This repo archives the random experiments I've done that seem valuable to share with the public, but not complete enough to be a project of their own.
Below is the list of the experiments done, linked to the respective sub-folders for each of the experiment.

List of experiments done (chronologically ordered)
---

### [Finding the gpu power sweet spot](./finding_the_gpu_power_sweet_spot/README.md) (2026/05/21)

Inspired by this [reddit post](https://www.reddit.com/r/LocalLLaMA/comments/1tayu5t/stop_wasting_electricity/), I decided to do an experiment to find the ideal power limit. The result isn't all that surprising, I ended up deciding to limit the clock speed to 2600 MHz for my 5090 when serving models.

![](finding_the_gpu_power_sweet_spot/graphs/t_s.png)