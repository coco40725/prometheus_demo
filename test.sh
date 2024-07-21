#!/bin/bash
for i in {1..10}
do
	curl http://localhost:8080/example/prime/${i}
done