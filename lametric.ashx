<%@ WebHandler Language="C#" Class="NSConvert1" %>

/*  LaMetric Nightscout monitor
    Copyright (C) 2018-2020 Martin Lukasek <martin@lukasek.cz>
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>. 
*/

using System;
using System.Net;
using System.Web;
using System.Web.Script.Serialization;
using System.Globalization;
using System.Collections.Generic;

public class NSConvert1 : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        string site = context.Request["site"];
        string units = context.Request["units"];
        string sgvlowstr = context.Request["low"];
        if(sgvlowstr!=null)
            sgvlowstr = sgvlowstr.Replace(',', '.');
        string sgvhighstr = context.Request["high"];
        if(sgvhighstr!=null)
            sgvhighstr = sgvhighstr.Replace(',', '.');
        string timeago = context.Request["timeago"];
        string chart = context.Request["chart"];
        string email = context.Request["email"];

        double sgvlow = 0;
        double.TryParse(sgvlowstr, out sgvlow);
        if (sgvlow == 0)
            sgvlow = (units == "mmol/L" ? 3.9 : 70);
        double sgvhigh = 0;
        double.TryParse(sgvhighstr, out sgvhigh);
        if (sgvhigh == 0)
            sgvhigh = (units == "mmol/L" ? 8.9 : 160);

        System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;

        string urlToJson1 = "https://"+site+"/api/v1/entries.json";
        string urlToJson2 = "https://"+site+"/api/v2/properties/bgnow,delta";

        JavaScriptSerializer jsonSerializer = new JavaScriptSerializer();

        using (WebClient wc = new WebClient())
        {
            context.Response.ContentType = "application/json";

            // begin JSON
            string respstr = "{\"frames\":[";

            if (site == null || site == "" || site == "yoursite.herokuapp.com")
            {
                respstr += "{\"text\":\"" + "Bad Nightscout site, please configure the Nightscout monitor App with your site." + "\",";
                respstr += "\"icon\":\"i26465";
                respstr += "\",\"index\":0}";
            } else
            {
                var json1 = wc.DownloadString(urlToJson1);
                var json2 = wc.DownloadString(urlToJson2);
                long epoch = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;

                JavaScriptSerializer serializer1 = new JavaScriptSerializer();
                serializer1.RegisterConverters(new[] { new DynamicJsonConverter() });
                dynamic data1 = serializer1.Deserialize(json1, typeof(object));

                JavaScriptSerializer serializer2 = new JavaScriptSerializer();
                serializer2.RegisterConverters(new[] { new DynamicJsonConverter() });
                dynamic data2 = serializer2.Deserialize(json2, typeof(object));

                long sensortime = data2.bgnow.mills / (long)1000;

                long sensordiff = epoch - sensortime;
                string direction = data2.bgnow.sgvs[0].direction;
                string iconstr;

                bool redicon = false;
                if (units == "mmol/L")
                {
                    redicon = ((data2.bgnow.last / 18f) <= sgvlow) || ((data2.bgnow.last / 18f) >= sgvhigh);
                } else {
                    redicon = (data2.bgnow.last <= sgvlow) || (data2.bgnow.last >= sgvhigh);
                }

                if (direction == "DoubleDown" || direction == "DOUBLE_DOWN")
                    iconstr = redicon ? "a30925" : "a30917";
                else
                    if (direction == "SingleDown" || direction == "SINGLE_DOWN")
                    iconstr = redicon ? "i30923" : "i30915";
                else
                        if (direction == "FortyFiveDown" || direction == "FORTY_FIVE_DOWN")
                    iconstr = redicon ? "i30919" : "i30911";
                else
                            if (direction == "Flat" || direction == "FLAT")
                    iconstr = redicon ? "i30921" : "i30913";
                else
                                if (direction == "FortyFiveUp" || direction == "FORTY_FIVE_UP")
                    iconstr = redicon ? "i30920" : "i30912";
                else
                                    if (direction == "SingleUp" || direction == "SINGLE_UP")
                    iconstr = redicon ? "i30922" : "i30914";
                else
                                        if (direction == "DoubleUp" || direction == "DOUBLE_UP")
                    iconstr = redicon ? "a30924" : "a30916";
                else
                                            if (direction == "NONE")
                    iconstr = "i3769";
                else
                                                if (direction == "NOT COMPUTABLE")
                    iconstr = "i3769";
                else
                    iconstr = "i3769";

                // SGV + DELTA
                respstr += "{\"text\":\"";
                if (units == "mmol/L")
                {
                    respstr += (data2.bgnow.last / 18f).ToString("0.0;-0.0;0");
                    respstr += (((float)data2.delta.mgdl) / 18f).ToString("+0.0;-0.0;+0");
                } else {
                    respstr += data2.bgnow.last.ToString();
                    respstr += data2.delta.mgdl.ToString("+0;-0;+0");
                }
                respstr += "\",\"icon\":\"" + iconstr + "\",\"index\":0}";

                // SENSOR TIME AGO
                if (timeago == "true" || timeago == "1")
                {
                    respstr += ",{\"text\":\"" + (sensordiff / 60.0).ToString("F0") + " min" + "\",\"icon\":\"";
                    respstr += sensordiff > 330 ? "i30926" : "i30918";
                    respstr += "\",\"index\":1}";
                }

                // SGV CHART
                if (chart == "true" || chart == "1")
                {
                    respstr += ",{\"chartData\":[";
                    int i;
                    int[] sgvdata = new int[10];
                    int zaps = 0;
                    for(i = 0; i<9; i++)
                    {
                        if(data1[i].type=="sgv" && zaps<9)
                        {
                            if (data1[i].sgv < 54)
                                sgvdata[zaps] = 0;
                            else
                                sgvdata[zaps] = data1[i].sgv-54;
                            zaps++;
                        }
                    }
                    for(i=zaps-1; i>=0; i--)
                    {
                        if (i >= 0 && i < zaps-1)
                            respstr += ",";
                        respstr += sgvdata[i].ToString();
                    }
                    respstr += "],\"index\":2}";
                }

            }

            // end JSON
            respstr += "]}";
            context.Response.Write(respstr);

        }
    }

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
}