# course-azure-container-debug-console-section-03



# Azure Container Debug Console

This guide helps you debug Azure Container Apps by inspecting configuration, checking environment variables, and installing Azure Functions Core Tools for local debugging inside the container.

## Why use these scripts?

Running these scripts inside your Linux container image helps:

- Detect missing dependencies.
- Surface errors that the regular Azure logs might miss.
- Provide a consistent way to inspect your container environment and debug Azure Functions.

---


## 0. Access the console Bash and check your function structure & Inspecting the Azure Functions Project Structure

![image](https://github.com/user-attachments/assets/d9835801-11e0-41f8-8de6-60a2e364e011)
Make sure you have at least one running container so that you can actually access the console bash.  Scale minimum to 1 if you scale minimum to 0 this won't work. 
# bash is more feature-rich and widely used in Linux environments and Azure containers.
# sh is more minimal and may not support all bash extensions.
 
Your Azure Functions project typically looks like this:

/
├── utils/ # Helper Python modules
│ ├── tester1.py
│ ├── statics.py
│ ├── other.py
│
├── venv/ # Python virtual environment (usually excluded from Docker)
├── .dockerignore # Files ignored by Docker build
├── .funcignore # Files ignored by Azure Functions build
├── .gitignore # Files ignored by Git
├── .gitlab-ci.yml # CI/CD pipeline config for GitLab
├── Dockerfile # Docker build instructions for containerizing your app
├── function_app.py # Main Azure Functions Python app file
├── host.json # Azure Functions host configuration
├── local.settings.json # Local app settings and environment variables exclude from your repo

---

## 1. Inspect the `host.json` File

The `host.json` file configures your Azure Functions host and controls runtime behavior.

### General Structure
json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond" : 5
      }
    }
  },
  "extensions": {
    "serviceBus": {
      "prefetchCount": 100,
      "messageHandlerOptions": {
        "maxConcurrentCalls": 16,
        "autoComplete": true
      }
    }
  }
}

##2 Run your function app locally  using SH:
Use .sh extension but run explicitly with bash when executing, update your linux container image using the scripts int his repo and test function from your console, this will detect some missing dependencies and errors the regular azure logs might miss.



## License

Course materials and documentation are licensed under [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License](https://creativecommons.org/licenses/by-nc-nd/4.0/).

You may use and share this content for personal and educational purposes with attribution.

Commercial use, redistribution, or modification without explicit permission is prohibited.

Code samples are licensed under the MIT License. See `LICENSE` for details.
