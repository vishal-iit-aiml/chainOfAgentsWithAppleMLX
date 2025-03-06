from typing import List, Optional, Iterator, Dict
from mlx_lm import load, generate

class WorkerAgent:
    """Worker agent that processes individual chunks of text using a local MLX model."""
    
    def __init__(self, model_path: str, system_prompt: str):
        """
        Initialize a worker agent with a local MLX model.
        
        Args:
            model_path: Path to the MLX model directory or HF repo (e.g., "mlx-community/Mistral-7B-Instruct-v0.3-4bit")
            system_prompt: The system prompt that defines the worker's role
        """
        self.model_path = model_path
        self.system_prompt = system_prompt
        self.model, self.tokenizer = load(path_or_hf_repo=model_path)
    
    def process_chunk(self, chunk: str, query: str, previous_cu: Optional[str] = None) -> str:
        """
        Process a single chunk of text using the local MLX model.
        
        Args:
            chunk: The text chunk to process
            query: The user's query
            previous_cu: The previous Cognitive Unit (CU) if any
            
        Returns:
            str: The processed output for this chunk
        """
        # Combine system prompt and user input into a single user message
        user_content = (
            f"{self.system_prompt}\n\n"
            f"Chunk: {chunk}\n"
            f"Query: {query}\n"
            f"Previous CU: {previous_cu or 'None'}"
        )
        conversation = [
            {"role": "user", "content": user_content}
        ]
        
        # Apply the chat template
        prompt = self.tokenizer.apply_chat_template(
            conversation=conversation,
            add_generation_prompt=True
        )
        
        # Generate response using MLX
        response = generate(
            model=self.model,
            tokenizer=self.tokenizer,
            prompt=prompt,
            max_tokens=512,
            verbose=False
        )
        
        return response.strip()

class ManagerAgent:
    """Manager agent that synthesizes outputs from worker agents using a local MLX model."""
    
    def __init__(self, model_path: str, system_prompt: str):
        """
        Initialize a manager agent with a local MLX model.
        
        Args:
            model_path: Path to the MLX model directory or HF repo (e.g., "mlx-community/Mistral-7B-Instruct-v0.3-4bit")
            system_prompt: The system prompt that defines the manager's role
        """
        self.model_path = model_path
        self.system_prompt = system_prompt
        self.model, self.tokenizer = load(path_or_hf_repo=model_path)
    
    def synthesize(self, worker_outputs: List[str], query: str) -> str:
        """
        Synthesize outputs from multiple worker agents using the local MLX model.
        
        Args:
            worker_outputs: List of outputs from worker agents
            query: The original user query
            
        Returns:
            str: The final synthesized response
        """
        combined_outputs = "\n\n".join(f"Worker {i+1}: {output}" 
                                    for i, output in enumerate(worker_outputs))
        
        # Combine system prompt and user input into a single user message
        user_content = (
            f"{self.system_prompt}\n\n"
            f"Worker Outputs:\n{combined_outputs}\n\n"
            f"Query: {query}"
        )
        conversation = [
            {"role": "user", "content": user_content}
        ]
        
        # Apply the chat template
        prompt = self.tokenizer.apply_chat_template(
            conversation=conversation,
            add_generation_prompt=True
        )
        
        # Generate response using MLX
        response = generate(
            model=self.model,
            tokenizer=self.tokenizer,
            prompt=prompt,
            max_tokens=1024,
            verbose=False
        )
        
        return response.strip()