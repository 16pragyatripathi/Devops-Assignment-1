# Fixed version of session6-7-docker/python-app/Dockerfile from the class repository.
# python:3.11-slim already ships python and pip, so the apt step is not needed
# (and "pip3" is not a Debian package name, which made the original build fail).
# The app has no dependencies, so there is no requirements.txt to copy.
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
