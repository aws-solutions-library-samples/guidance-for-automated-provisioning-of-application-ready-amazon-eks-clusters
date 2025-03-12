import requests
import json
import time
import os
import wave
import logging
from typing import Dict, Optional, Generator
from datetime import datetime
import subprocess
import platform
import sseclient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def play_notification(success: bool = True):
    """Play a notification sound using system sound."""
    if platform.system() == "Darwin":  # macOS
        sound = "Glass" if success else "Basso"
        subprocess.run(["afplay", f"/System/Library/Sounds/{sound}.aiff"])
    else:  # Linux/Windows - print ASCII bell character
        print("\a")

def play_audio_file(file_path: str):
    """Play an audio file using system audio player."""
    logger.info(f"Playing audio file: {file_path}")
    if platform.system() == "Darwin":  # macOS
        subprocess.run(["afplay", file_path])
    elif platform.system() == "Linux":
        subprocess.run(["aplay", file_path])
    elif platform.system() == "Windows":
        subprocess.run(["start", file_path], shell=True)
    else:
        logger.warning(f"Audio playback not supported on {platform.system()}")

class IntegrationTest:
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url.rstrip('/')
        self.test_results = []
        self.test_dir = "test_outputs"
        os.makedirs(self.test_dir, exist_ok=True)

    def _make_request(self, endpoint: str, method: str = "GET", data: Optional[Dict] = None, stream: bool = False) -> requests.Response:
        url = f"{self.base_url}{endpoint}"
        try:
            if method == "GET":
                response = requests.get(url, stream=stream)
            elif method == "POST":
                response = requests.post(url, json=data, stream=stream)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            return response
        except requests.exceptions.RequestException as e:
            logger.error(f"Request failed: {str(e)}")
            raise

    def test_chat_endpoint(self, input_text: str, streaming: bool = True) -> Dict:
        """Test the chat endpoint and return the response."""
        logger.info(f"Testing {'streaming' if streaming else 'regular'} chat endpoint with input: {input_text}")
        
        start_time = time.time()
        
        if streaming:
            return self.test_streaming_chat(input_text)
        else:
            return self.test_regular_chat(input_text)

    def test_regular_chat(self, input_text: str) -> Dict:
        """Test the regular (non-streaming) chat endpoint."""
        response = self._make_request(
            "/api/chat",
            method="POST",
            data={"input": input_text}
        )
        duration = time.time() - start_time

        result = {
            "test_name": "chat_endpoint",
            "input": input_text,
            "status_code": response.status_code,
            "duration": duration,
            "timestamp": datetime.now().isoformat()
        }

        if response.status_code == 200:
            result["success"] = True
            result["response"] = response.json()
            logger.info(f"Chat response received: {result['response']}")
            
            # If we got an audio URL, test it immediately
            if "audio_url" in result["response"]:
                audio_result = self.test_audio_endpoint(result["response"]["audio_url"])
                result["audio_result"] = audio_result
        else:
            result["success"] = False
            result["error"] = response.text
            logger.error(f"Chat request failed: {response.text}")

        self.test_results.append(result)
        return result

    def test_streaming_chat(self, input_text: str) -> Dict:
        """Test the streaming chat endpoint."""
        start_time = time.time()
        response = self._make_request(
            "/api/chat/stream",
            method="POST",
            data={"input": input_text},
            stream=True
        )
        
        result = {
            "test_name": "streaming_chat_endpoint",
            "input": input_text,
            "status_code": response.status_code,
            "timestamp": datetime.now().isoformat(),
            "updates": []
        }

        if response.status_code == 200:
            try:
                client = sseclient.SSEClient(response)
                for event in client.events():
                    try:
                        data = json.loads(event.data)
                        if data["type"] == "update":
                            logger.info(f"Received update: {data['text']}")
                            if "audio_url" in data:
                                audio_result = self.test_audio_endpoint(data["audio_url"])
                                data["audio_result"] = audio_result
                            result["updates"].append(data)
                        elif data["type"] == "error":
                            logger.error(f"Received error: {data['message']}")
                            result["success"] = False
                            result["error"] = data["message"]
                            break
                        elif data["type"] == "done":
                            logger.info("Stream completed")
                            break
                    except json.JSONDecodeError as e:
                        logger.error(f"Failed to parse SSE data: {e}")
                        continue

                result["success"] = True
            except Exception as e:
                result["success"] = False
                result["error"] = str(e)
                logger.error(f"Streaming error: {str(e)}")
        else:
            result["success"] = False
            result["error"] = response.text
            logger.error(f"Streaming request failed: {response.text}")

        result["duration"] = time.time() - start_time
        self.test_results.append(result)
        return result

    def test_audio_endpoint(self, audio_url: str) -> Dict:
        """Test the audio endpoint and verify the audio file."""
        logger.info(f"Testing audio endpoint: {audio_url}")
        
        start_time = time.time()
        response = self._make_request(audio_url)
        duration = time.time() - start_time

        result = {
            "test_name": "audio_endpoint",
            "audio_url": audio_url,
            "status_code": response.status_code,
            "duration": duration,
            "timestamp": datetime.now().isoformat()
        }

        if response.status_code == 200:
            # Save and verify audio file
            filename = f"{self.test_dir}/test_audio_{int(time.time())}.wav"
            with open(filename, "wb") as f:
                f.write(response.content)

            # Verify WAV file format
            try:
                with wave.open(filename, "rb") as wav_file:
                    result["success"] = True
                    result["audio_details"] = {
                        "channels": wav_file.getnchannels(),
                        "sample_width": wav_file.getsampwidth(),
                        "frame_rate": wav_file.getframerate(),
                        "frames": wav_file.getnframes(),
                        "file_size": os.path.getsize(filename)
                    }
                logger.info(f"Audio file saved and verified: {filename}")
                # Play the audio file
                play_audio_file(filename)
            except Exception as e:
                result["success"] = False
                result["error"] = f"Invalid WAV file: {str(e)}"
                logger.error(f"Audio file verification failed: {str(e)}")
        else:
            result["success"] = False
            result["error"] = response.text
            logger.error(f"Audio request failed: {response.text}")

        self.test_results.append(result)
        return result

    def run_full_integration_test(self, test_cases: list, streaming: bool = True) -> Dict:
        """Run a complete integration test with multiple test cases."""
        overall_results = {
            "total_tests": len(test_cases),
            "successful_tests": 0,
            "failed_tests": 0,
            "test_cases": [],
            "streaming_mode": streaming
        }

        for test_case in test_cases:
            logger.info(f"\nRunning test case: {test_case}")
            
            # Test chat endpoint
            chat_result = self.test_chat_endpoint(test_case, streaming=streaming)
            
            # For streaming mode, success is based on all updates succeeding
            if streaming:
                test_success = chat_result["success"] and all(
                    update.get("audio_result", {}).get("success", False)
                    for update in chat_result.get("updates", [])
                    if "audio_url" in update
                )
            else:
                # For regular mode, success is based on chat and audio both working
                test_success = chat_result["success"]
                if "audio_result" in chat_result:
                    test_success = test_success and chat_result["audio_result"]["success"]

            if test_success:
                overall_results["successful_tests"] += 1
                play_notification(True)  # Success sound
            else:
                overall_results["failed_tests"] += 1
                play_notification(False)  # Failure sound

            overall_results["test_cases"].append({
                "input": test_case,
                "chat_result": chat_result
            })

            # Add a small delay between test cases
            time.sleep(1)

        # Calculate success rate
        overall_results["success_rate"] = (
            overall_results["successful_tests"] / overall_results["total_tests"]
            if overall_results["total_tests"] > 0 else 0
        )

        return overall_results

    def save_results(self, results: Dict):
        """Save test results to a JSON file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{self.test_dir}/test_results_{timestamp}.json"
        
        with open(filename, "w") as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"Test results saved to {filename}")

def main():
    # Test cases with various scenarios
    test_cases = [
        #"I want you to write an essay about the importance of AI in the future",
        "Explain how a rainbow forms in simple terms.",
        "Tell me a short story about a brave knight.",
        "What is the capital of France?",
        "Generate a haiku about spring.",
        
    ]

    # Initialize and run tests
    test = IntegrationTest()
    
    try:
        logger.info("Starting integration tests...")
        # Run streaming tests first
        logger.info("\nRunning streaming tests...")
        streaming_results = test.run_full_integration_test(test_cases, streaming=True)
        test.save_results(streaming_results)
        
        # Then run regular tests
        logger.info("\nRunning regular tests...")
        regular_results = test.run_full_integration_test(test_cases, streaming=False)
        test.save_results(regular_results)
        
        # Print summary for both
        logger.info("\nStreaming Test Summary:")
        logger.info(f"Total Tests: {streaming_results['total_tests']}")
        logger.info(f"Successful: {streaming_results['successful_tests']}")
        logger.info(f"Failed: {streaming_results['failed_tests']}")
        logger.info(f"Success Rate: {streaming_results['success_rate']*100:.2f}%")
        
        logger.info("\nRegular Test Summary:")
        logger.info(f"Total Tests: {regular_results['total_tests']}")
        logger.info(f"Successful: {regular_results['successful_tests']}")
        logger.info(f"Failed: {regular_results['failed_tests']}")
        logger.info(f"Success Rate: {regular_results['success_rate']*100:.2f}%")
        
        # Play final summary sound based on both test sets
        overall_success = (streaming_results['failed_tests'] + regular_results['failed_tests']) == 0
        play_notification(overall_success)
        
    except Exception as e:
        logger.error(f"Test execution failed: {str(e)}")
        play_notification(False)  # Error sound
        raise

if __name__ == "__main__":
    main() 