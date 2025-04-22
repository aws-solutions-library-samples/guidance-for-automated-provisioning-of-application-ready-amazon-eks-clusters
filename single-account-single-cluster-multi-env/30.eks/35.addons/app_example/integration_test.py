import logging
import json
import aiohttp
import asyncio
from typing import List, Dict
import sounddevice as sd
import soundfile as sf
import tempfile
import os

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IntegrationTest:
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url.rstrip('/')
        self.session = None
        self.temp_dir = tempfile.mkdtemp()
        self.test_results = []

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
        # Cleanup temp directory
        try:
            for file in os.listdir(self.temp_dir):
                os.remove(os.path.join(self.temp_dir, file))
            os.rmdir(self.temp_dir)
        except Exception as e:
            logger.warning(f"Failed to cleanup temp directory: {e}")

    async def play_audio(self, audio_url: str) -> bool:
        """Download and play audio from URL."""
        try:
            # Download the audio file
            async with self.session.get(f"{self.base_url}{audio_url}") as response:
                if response.status != 200:
                    logger.error(f"Failed to download audio: {response.status}")
                    return False

                # Save to temporary file
                temp_path = os.path.join(self.temp_dir, "temp_audio.wav")
                with open(temp_path, "wb") as f:
                    f.write(await response.read())

                # Play the audio
                logger.info("Playing audio response...")
                data, samplerate = sf.read(temp_path)
                sd.play(data, samplerate)
                sd.wait()  # Wait until audio is finished playing

                # Clean up
                os.remove(temp_path)
                return True

        except Exception as e:
            logger.error(f"Error playing audio: {e}")
            return False

    async def test_chat_stream(self, message: str) -> Dict:
        """Test the streaming chat endpoint."""
        result = {
            "input": message,
            "success": False,
            "received_text": False,
            "received_audio": False,
            "error": None
        }

        try:
            async with self.session.post(
                f"{self.base_url}/api/chat/stream",
                json={"input": message},
                headers={"Accept": "text/event-stream"}
            ) as response:
                if response.status != 200:
                    error_msg = f"Request failed with status {response.status}"
                    logger.error(error_msg)
                    result["error"] = error_msg
                    return result

                # Process the SSE stream
                async for line in response.content:
                    try:
                        line = line.decode('utf-8').strip()
                        if not line or not line.startswith('data: '):
                            continue

                        data = json.loads(line[6:])  # Remove 'data: ' prefix
                        logger.debug(f"Received event: {data}")

                        if data.get('type') == 'error':
                            error_msg = f"Server error: {data.get('message')}"
                            logger.error(error_msg)
                            result["error"] = error_msg
                            return result

                        if data.get('type') == 'update':
                            result["received_text"] = True
                            logger.info(f"Received text: {data.get('text', '')}")
                            if 'audio_url' in data:
                                logger.info(f"Audio URL: {data['audio_url']}")
                                audio_success = await self.play_audio(data['audio_url'])
                                result["received_audio"] = audio_success

                        if data.get('type') == 'done':
                            logger.info("Stream completed")
                            break

                    except json.JSONDecodeError as e:
                        logger.warning(f"Failed to parse SSE data: {e}")
                        continue
                    except Exception as e:
                        error_msg = f"Error processing event: {e}"
                        logger.error(error_msg)
                        result["error"] = error_msg
                        return result

                result["success"] = result["received_text"]
                return result

        except Exception as e:
            error_msg = f"Test failed: {e}"
            logger.error(error_msg)
            result["error"] = error_msg
            return result

    async def run_tests(self, test_cases: List[str]) -> Dict:
        """Run all test cases and return detailed results."""
        results = {
            "total_tests": len(test_cases),
            "successful_tests": 0,
            "failed_tests": 0,
            "success_rate": 0.0,
            "test_cases": []
        }

        for test_case in test_cases:
            logger.info(f"\nTesting with input: {test_case}")
            test_result = await self.test_chat_stream(test_case)
            results["test_cases"].append(test_result)
            
            if test_result["success"]:
                results["successful_tests"] += 1
                logger.info("✓ Test passed")
                if test_result["received_audio"]:
                    logger.info("✓ Audio playback successful")
            else:
                results["failed_tests"] += 1
                logger.error("✗ Test failed")
                if test_result["error"]:
                    logger.error(f"Error: {test_result['error']}")

        # Calculate success rate
        results["success_rate"] = (results["successful_tests"] / results["total_tests"]) * 100

        # Print summary
        logger.info("\nTest Summary:")
        logger.info(f"Total Tests: {results['total_tests']}")
        logger.info(f"Successful: {results['successful_tests']}")
        logger.info(f"Failed: {results['failed_tests']}")
        logger.info(f"Success Rate: {results['success_rate']:.2f}%")

        return results

async def main():
    # Test cases
    test_cases = [
        "Two cloud architects from HDI are looking if they can get rid of the platform team and use EKS Auto mode",
        "Tell me a short story about a brave knight."
    ]

    logger.info("Starting integration tests...")
    async with IntegrationTest() as test:
        results = await test.run_tests(test_cases)
        
        if results["success_rate"] == 100:
            logger.info("\n✓ All tests passed successfully!")
        else:
            logger.error("\n✗ Some tests failed")
            exit(1)

if __name__ == "__main__":
    asyncio.run(main()) 