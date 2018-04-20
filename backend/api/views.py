from django.shortcuts import render

# Create your views here.

from django.http import HttpResponse
import json
import datetime
import sys

result = "{}"
def index(request):
    if request.GET["id"] == "api1" :
        test_str = request.GET["api1"]


    elif request.GET["id"] == "api2" :
        test_str = request.GET["api2"]

    return HttpResponse(result)