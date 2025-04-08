# Yuelao

Yuelao is a game manager library for Love2D. It provides a unified foundation to build on, including - among other things - a scene graph, messaging system, input handling, and a class system with mixins. More accurately, it's a sort of engine or sub-framework for Love2D.

It was primarily made for personal use, so it's more opinionated and far-reaching than best practice for libraries dictates. Nonetheless it is completely useable and thoroughly-documented, so if nothing else it may serve as inspiration for others.

Internally, Yuelao is fundamentally modular. Many small individual subsystems modify a very minimal core; it's sort of like an ECS with only one entity, built up piece by piece. Built on top of this engine layer is a