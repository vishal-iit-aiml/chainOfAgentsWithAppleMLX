from flask import Flask, request, jsonify
from chain_of_agents import ChainOfAgents
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

app = Flask(__name__)
coa = ChainOfAgents(
    worker_model="gpt-3.5-turbo",
    manager_model="gpt-4",
    chunk_size=2000
)

@app.route('/process', methods=['POST'])
def process_text():
    data = request.json
    input_text = data.get('text')
    query = data.get('query')
    
    try:
        result = coa.process(input_text, query)
        return jsonify({'result': result})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000) 