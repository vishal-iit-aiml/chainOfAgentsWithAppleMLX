from mlx_lm import load, generate

model, tokenizer = load("mistralai/Mistral-7B-Instruct-v0.3")
response = generate(model, tokenizer, prompt="Test", max_tokens=10, temperature=0.3, verbose=True)
print(response)