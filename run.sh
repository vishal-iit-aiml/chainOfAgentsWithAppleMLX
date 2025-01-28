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
from chain_of_agents.utils import read_pdf
import os
from dotenv import load_dotenv
import pathlib
import sys

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
    chunk_size=500  # Reduced chunk size for better handling
)

# Read PDF file
pdf_path = "DeepSeek_R1.pdf"  # Updated to your PDF file
if not os.path.exists(pdf_path):
    print(f"Error: PDF file not found at {pdf_path}")
    sys.exit(1)

input_text = read_pdf(pdf_path)
query = "What are the key findings and contributions of this research paper about Chain of Agents?"  # Updated query for your paper

# Process the text
result = coa.process(input_text, query)
print("\nQuery:", query)
print("\nResult:", result)
EOF

# Deactivate virtual environment
deactivate

echo "Done!" 