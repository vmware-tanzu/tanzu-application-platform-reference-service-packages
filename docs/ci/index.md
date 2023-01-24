---
title: Continuous Integration
---

Continuous integration practices help reduce time-consuming activities as well as human errors,
by defining some standards and automating operations, such as builds and tests.

In order to maintain a clean and working main branch that can be a trusted source of code and documentation,
any change to its content should be made only via pull requests (PR).
In fact, the PR-related events can trigger workflows to run some repetitive tasks that can be automated, i.e. tests,
thus reducing the toil on code maintainers.

This repository features a few GitHub Actions workflows to handle different components, such as:

- [Documentation](./documentation.md)
- [Carvel and Crossplane packages](./carvel-crossplane-packages.md)
- Carvel repository

!!! note
    [GitHub Actions reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) are being used in order to simplify
    writing and managing pipelines, that become more readable and easier to maintain, as well as make it possible to effectively reuse them
    in different pipelines to respond to different events.

    They allow to write specific workflows like functions in programming languages, that can read inputs and produce outputs
    that can be passed along to other workflows.
    It's important to highlight two things that might not be trivial:

    1. Environment variables are not transferred from the parent workflow to its children.
       In order to pass values from one to the others, inputs/outputs shall be used.
    1. Secrets are not immediately visible in children workflows:
       they must either be defined one by one or declare explicit inheritance. More info [here](https://docs.github.com/en/actions/using-workflows/reusing-workflows#passing-secrets-to-nested-workflows). 
