#!/bin/bash

# Exit on error
set -e

# Activate virtual environment
source venv/bin/activate

# Run the API server
python api.py

# Deactivate when done (though this won't be reached while server is running)
deactivate 