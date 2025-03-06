#!/bin/bash

# Exit on error
set -e

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install requirements
echo "Installing requirements..."
pip install -r requirements.txt

# Ensure Hugging Face CLI is authenticated
echo "Checking Hugging Face authentication..."
if ! huggingface-cli whoami > /dev/null 2>&1; then
    echo "Please log in to Hugging Face CLI:"
    huggingface-cli login
fi

# Run example
echo "Running Chain of Agents example with local MLX model..."
python3 - << EOF
from chain_of_agents import ChainOfAgents
from chain_of_agents.utils import read_pdf, split_into_chunks
from chain_of_agents.agents import WorkerAgent, ManagerAgent
import os
import sys

# Initialize Chain of Agents with quantized MLX model
coa = ChainOfAgents(
    worker_model_path="mlx-community/Mistral-7B-Instruct-v0.3-4bit",  # Updated to 4-bit model
    manager_model_path="mlx-community/Mistral-7B-Instruct-v0.3-4bit",  # Updated to 4-bit model
    chunk_size=500
)

# Read PDF file
pdf_path = "DeepSeek_R1.pdf"
if not os.path.exists(pdf_path):
    print(f"Error: PDF file not found at {pdf_path}")
    sys.exit(1)

input_text = read_pdf(pdf_path)
query = "What are the key features, capabilities, and technical specifications of the DeepSeek R1 model? Please include any benchmark results or performance comparisons mentioned in the paper."

# Process the text
print("\nProcessing document with Chain of Agents...\n")

chunks = split_into_chunks(input_text, coa.chunk_size, coa.worker_model_path)
worker_outputs = []
previous_cu = None

print("=" * 80)
print("WORKER RESPONSES")
print("=" * 80 + "\n")

for i, chunk in enumerate(chunks):
    print(f"\n{'='*30} Worker {i+1}/{len(chunks)} {'='*30}")
    worker = WorkerAgent(coa.worker_model_path, coa.worker_prompt)
    output = worker.process_chunk(chunk, query, previous_cu)
    worker_outputs.append(output)
    previous_cu = output
    print(f"\n{output}\n")

print("\n" + "=" * 80)
print("MANAGER SYNTHESIS")
print("=" * 80 + "\n")

manager = ManagerAgent(coa.manager_model_path, coa.manager_prompt)
final_output = manager.synthesize(worker_outputs, query)
print(final_output)

print("\n" + "=" * 80)
EOF

# Deactivate virtual environment
deactivate

echo "Done!"