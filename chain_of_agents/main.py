from typing import Optional, Iterator, Dict
from .agents import WorkerAgent, ManagerAgent
from .utils import split_into_chunks, get_default_prompts
import logging
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChainOfAgents:
    """Main class for the Chain of Agents implementation with local MLX models."""
    
    def __init__(
        self,
        worker_model_path: str = "mlx-community/Mistral-7B-Instruct-v0.3-4bit",  # Updated to 4-bit model
        manager_model_path: str = "mlx-community/Mistral-7B-Instruct-v0.3-4bit",  # Updated to 4-bit model
        chunk_size: int = 500,
        worker_prompt: Optional[str] = None,
        manager_prompt: Optional[str] = None
    ):
        """
        Initialize the Chain of Agents with local MLX models.
        
        Args:
            worker_model_path: Path or HF repo to the worker MLX model
            manager_model_path: Path or HF repo to the manager MLX model
            chunk_size: Maximum tokens per chunk
            worker_prompt: Custom system prompt for workers
            manager_prompt: Custom system prompt for manager
        """
        default_worker_prompt, default_manager_prompt = get_default_prompts()
        
        self.worker_prompt = worker_prompt or default_worker_prompt
        self.manager_prompt = manager_prompt or default_manager_prompt
        self.chunk_size = chunk_size
        self.worker_model_path = worker_model_path
        self.manager_model_path = manager_model_path
        
        logger.info(f"Initialized Chain of Agents with worker model {worker_model_path} and manager model {manager_model_path}")
    
    def process(self, input_text: str, query: str) -> str:
        """Process a long text input using the Chain of Agents."""
        chunks = split_into_chunks(input_text, self.chunk_size, self.worker_model_path)
        
        worker_outputs = []
        previous_cu = None
        
        for i, chunk in enumerate(chunks):
            logger.info(f"Processing chunk {i+1}/{len(chunks)}")
            worker = WorkerAgent(self.worker_model_path, self.worker_prompt)
            output = worker.process_chunk(chunk, query, previous_cu)
            worker_outputs.append(output)
            previous_cu = output
        
        manager = ManagerAgent(self.manager_model_path, self.manager_prompt)
        final_output = manager.synthesize(worker_outputs, query)
        
        return final_output 
    
    def process_stream(self, input_text: str, query: str) -> Iterator[Dict[str, str]]:
        """Process text with streaming - yields worker and manager messages."""
        worker_outputs = []
        previous_cu = None
        
        chunks = split_into_chunks(input_text, self.chunk_size, self.worker_model_path)
        total_chunks = len(chunks)
        
        yield {"type": "metadata", "content": json.dumps({"total_chunks": total_chunks, "total_pages": getattr(input_text, 'total_pages', 0)})}
        
        for i, chunk in enumerate(chunks):
            logger.info(f"Processing chunk {i+1}/{total_chunks}")
            worker = WorkerAgent(self.worker_model_path, self.worker_prompt)
            output = worker.process_chunk(chunk, query, previous_cu)
            worker_outputs.append(output)
            previous_cu = output
            
            yield {
                "type": "worker",
                "content": output,
                "progress": {"current": i + 1, "total": total_chunks}
            }
        
        logger.info("Processing manager synthesis")
        manager = ManagerAgent(self.manager_model_path, self.manager_prompt)
        final_output = manager.synthesize(worker_outputs, query)
        
        yield {"type": "manager", "content": final_output}