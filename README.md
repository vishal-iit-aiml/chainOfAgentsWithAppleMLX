# Chain of Agents Implementation

Chain of Agents (CoA) implementation in Python and Swift - A framework for long-context tasks using Large Language Models (LLMs).

## Overview

This repository implements the Chain-of-Agents framework as described in:

- [Chain of Agents: Large language models collaborating on long-context tasks](https://research.google/blog/chain-of-agents-large-language-models-collaborating-on-long-context-tasks/) (Google Research Blog)
- [Chain of Agents Paper](https://openreview.net/pdf?id=LuCLf4BJsr) (Research Paper)

The Chain of Agents framework enables efficient processing of long-context tasks by:
1. Breaking down large inputs into manageable chunks
2. Using worker agents to process individual chunks
3. Employing a manager agent to synthesize results

## Installation

```bash
git clone https://github.com/rudrankriyam/chain-of-agents.git
cd chain-of-agents
pip install -r requirements.txt
```

## Usage

To run the Chain of Agents implementation, use the following command:

### Initialize the chain

```python
coa = ChainOfAgents(
worker_model="gpt-3.5-turbo",
manager_model="gpt-4",
chunk_size=2000
)
```

### Process a long document

```python
result = coa.process(
input_text="Your long text here...",
query="What are the main themes in this text?"
)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

```bibtex
@article{zhang2024chain,
title={Chain of Agents: Large Language Models Collaborating on Long-Context Tasks},
author={Zhang, Yusen and Sun, Ruoxi and Chen, Yanfei and Pfister, Tomas and Zhang, Rui and Arık, Sercan Ö.},
journal={arXiv preprint arXiv:2404.08392},
year={2024}
}
```