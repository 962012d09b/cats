from setuptools import setup, find_packages

setup(
    name="cats_backend",
    version="1.0.0",
    packages=find_packages("./", exclude=["*tests"]),
    package_dir={"": "./"},
    install_requires=[
        "flask",
        "flask-cors",
        "flask-marshmallow",
        "flask-sqlalchemy",
        "marshmallow",
        "marshmallow-sqlalchemy",
        "sqlalchemy",
        "waitress",
        "pytest",
        "coverage",
        "setuptools",
    ],
    entry_points={
        "console_scripts": [
            "cats_backend = main:run",
        ]
    },
)
