# Contributing to the Spyderisk Deployment Project

Welcome!

We'd love to have your contributions to Spyderisk deployment. This document is about our practical principles of working. 

The overall Spyderisk mission is to:

> understand the trustworthiness of socio-technical systems by establishing an
> international Open Community supporting the research, development, use and
> support of open, effective, and accessible risk assessment methods, knowledge
> and tools.

and you can read more about this in the [general Spyderisk description](https://github.com/Spyderisk/), which explains
who we are and who Spyderisk is intended for.

Please read our [Code of Conduct](../CODE-OF-CONDUCT.md) to keep our community approachable and
respectful.

# Who can contribute?

This deployment project is about the infrastructure around running the Spyderisk modeller. If you know 
about the technologies of Docker, Gradle, Keycloak and nginx then you'll be able to see how the 
stack is put together and no doubt how to improve it. Plus of course we welcome fixes to the documentation.

That said, you don't need to be a coder to contribute.

Do please drop an email or open a discussion issue on GitHub.

# Getting started

The recipes and scripts in this project automate the details of installing Spyderisk as explained in
the [system modeller README](https://github.com/Spyderisk/system-modeller/blob/dev/README.md)
explains how to set up the development environment. So as you explore what we have done you'll be able to
see what needs work.

Alternatively you can find an issue from our
[List of Open Deployment Issues](https://github.com/Spyderisk/system-modeller-deployment/issues),
or just create a new query or bug report as described in the following section.

Whatever you decide to work on, follow the "How to submit a patch" procedure below

# How to open a query or bug report

* Open a [new issue in system-modeller-deployment](https://github.com/Spyderisk/system-modeller-deployment/issues/new)
* Select the template marked "New Spyderisk Deployment query", or "New Spyderisk Deployment bug report"

# How to submit a patch

You are about to make us very happy. There are several cases:

* Documentation fix - [create a fork and send a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork)
* Obvious code fix - create a fork and pull request, just as for documentation
* Any other code fix - please create a query or bug report according to the previous section. It may well be that you have code which is good to go, but in our young open project there is a lot of context that might be relevant to what you wish to do.

But basically just talk to us using whatever means you are comfortable with, and we will figure it out.

# Spyderisk project principles

## Openness first

* Our [software licensing is Apache 2](./LICENSING.md), and analogously for documentation
* Our communication is collaborative and collective
* We build our software around openly published academic theory

## Transparency trumps accuracy

Spyderisk needs to be both trustable and also to progress quickly. Where there
is incomplete or inaccurate work in the Spyderisk deployment code then we document
this with the string:

```
WIP: BRIEF TEXT DESCRIPTION, https://github.com/Spyderisk/system-modeller-deployment/issues/NNN
```

Where "BRIEF TEXT DESCRIPTION" should not exceed a couple of sentences, and NNN
should be the most relevant issue.

