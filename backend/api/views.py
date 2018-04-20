from django.shortcuts import render

# Create your views here.

from django.http import HttpResponse
import json
import datetime
import sys

result = "{}"
def index(request):
    if request.GET["id"] == "nlp1" :
        test_str = request.GET["keyword"]


    elif request.GET["id"] == "nlp2" :
        test_str = request.GET["menu_list"]

    return HttpResponse(result)