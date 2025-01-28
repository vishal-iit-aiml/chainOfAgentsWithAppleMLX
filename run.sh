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
pip install groq

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    echo "GROQ_API_KEY=" > .env
    echo "Please add your Groq API key to the .env file"
    exit 1
fi

# Run example
echo "Running Chain of Agents example..."
python3 - << EOF
from chain_of_agents import ChainOfAgents
import os
from dotenv import load_dotenv
import pathlib

# Load environment variables
env_path = pathlib.Path('.') / '.env'
load_dotenv(dotenv_path=env_path)

# Verify API key is loaded
if not os.getenv("GROQ_API_KEY"):
    raise ValueError("GROQ_API_KEY not found in environment variables")

# Initialize Chain of Agents
coa = ChainOfAgents(
    worker_model="llama-3.3-70b-versatile",
    manager_model="llama-3.3-70b-versatile",
    chunk_size=2000
)

# Example text and query
input_text = """
The Chain of Agents (CoA) framework is designed to handle long-context tasks by breaking them down into manageable chunks. 
Each chunk is processed by a worker agent, and their outputs are synthesized by a manager agent to produce a final response.
This approach enables effective processing of documents that exceed the context window of individual language models.
"""

query = "What is the main purpose of the Chain of Agents framework?"

# Process the text
result = coa.process(input_text, query)
print("\nQuery:", query)
print("\nResult:", result)
EOF

# Deactivate virtual environment
deactivate

echo "Done!" 