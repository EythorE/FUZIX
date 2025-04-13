all: lena.simg

lena.simg: venv create_image.py
	. venv/bin/activate && \
	python3 create_image.py --all

venv:
	python3 -m venv venv && \
	. venv/bin/activate && \
	pip install -r requirements.txt

clean:
	rm -rf *.simg venv
