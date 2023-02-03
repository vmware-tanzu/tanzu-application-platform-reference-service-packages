---
title: Continuous Integration
---

Continuous integration practices help reduce time-consuming activities as well as human errors,
by defining some standards and automating operations, such as builds and tests.

To maintain a clean and working main branch that can be a trusted source of code and documentation, we make changes exclusively via a pull request(PR).

The PR-related events trigger workflows to run repetitive tasks that can are automated, such as tests,
thus reducing the toil on code maintainers.

This repository features a few GitHub Actions workflows to handle different components, such as:

- [Documentation](./documentation.md)
- [Carvel and Crossplane packages](./carvel-crossplane-packages.md)
- Carvel repository

!!! note
    [GitHub Actions reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) are being used in order to simplify
    writing and managing pipelines that become more readable and easier to maintain, as well as making it possible to reuse them effectively
    in other pipelines to respond to different events.

    They allow writing specific workflows, like functions in programming languages. These workflows can read inputs and produce outputs
    that they pass along to other workflows.
    It's important to highlight two things that might not be trivial:

    1. A workflow does not automatically transfer Environment variables to its children.
       To pass values from one to the others, you use the inputs/outputs.
    1. Secrets are not immediately visible in children's workflows:
       They must either be defined one by one or declare explicit inheritance. More info [here](https://docs.github.com/en/actions/using-workflows/reusing-workflows#passing-secrets-to-nested-workflows). 
