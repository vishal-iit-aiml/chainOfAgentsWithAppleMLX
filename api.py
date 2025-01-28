from flask import Flask, request, jsonify, Response, stream_with_context
from chain_of_agents import ChainOfAgents
from dotenv import load_dotenv
import json
import os

# Load environment variables
load_dotenv()

app = Flask(__name__)
coa = ChainOfAgents(
    worker_model="meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
    manager_model="meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
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

@app.route('/process-stream', methods=['POST'])
def process_stream():
    data = request.json
    input_text = data.get('text')
    query = data.get('query')
    
    def generate():
        try:
            for message in coa.process_stream(input_text, query):
                yield f"data: {json.dumps(message)}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'content': str(e)})}\n\n"
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')

if __name__ == '__main__':
    app.run(port=5000) 