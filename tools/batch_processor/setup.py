from setuptools import setup, find_packages

setup(
    name="batch_processor",
    version="1.0.0",
    packages=find_packages(exclude=["*tests"]),
    install_requires=[
        "pytest",
        "rich",
        "pyyaml",
        "setuptools",
        "cats_backend",
    ],
    entry_points={
        "console_scripts": [
            "batch_processor = batch_processor.main:main",
        ]
    },
)
