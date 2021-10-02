<%@ WebHandler Language="C#" Class="NSConvert1" %>

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
        string token = context.Request["token"];
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

        string urlToJson1 = "";
        string urlToJson2 = "";

        if (site.Contains("sugarmate.io"))
        {
            urlToJson1 = "https://sugarmate.io/api/v1/" + token + "/latest.json";
        } else
        {
            urlToJson1 = "https://"+site+"/api/v1/entries.json";
            urlToJson2 = "https://"+site+"/api/v2/properties/bgnow,delta";
            if (!string.IsNullOrEmpty(token))
            {
                if (token != "null" && token != "<null>")
                {
                    urlToJson1 += "?token=" + token;
                    urlToJson2 += "?token=" + token;
                }
            }
        }

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
                string json1 = "";
                string json2 = "";
                HttpStatusCode dsStatus = HttpStatusCode.OK;

                try
                {
                    json1 = wc.DownloadString(urlToJson1);
                    if (!site.Contains("sugarmate.io"))
                        json2 = wc.DownloadString(urlToJson2);
                }
                catch (WebException e)
                {
                    using (WebResponse response = e.Response)
                    {
                        HttpWebResponse httpResponse = (HttpWebResponse) response;
                        dsStatus = httpResponse.StatusCode;
                    }

                }

                long epoch = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;

                if (dsStatus == HttpStatusCode.OK)
                {
                    JavaScriptSerializer serializer1 = new JavaScriptSerializer();
                    serializer1.RegisterConverters(new[] { new DynamicJsonConverter() });
                    dynamic data1 = serializer1.Deserialize(json1, typeof(object));

                    if (!site.Contains("sugarmate.io"))
                    {
                        // Nightscout

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
                            for (i = 0; i < 9; i++)
                            {
                                if (data1[i].type == "sgv" && zaps < 9)
                                {
                                    if (data1[i].sgv < 54)
                                        sgvdata[zaps] = 0;
                                    else
                                        sgvdata[zaps] = data1[i].sgv - 54;
                                    zaps++;
                                }
                            }
                            for (i = zaps - 1; i >= 0; i--)
                            {
                                if (i >= 0 && i < zaps - 1)
                                    respstr += ",";
                                respstr += sgvdata[i].ToString();
                            }
                            respstr += "],\"index\":2}";
                        }
                    }
                    else
                    {
                        // sugarmate.io

                        if(data1.x == null)
                        {   
                            if(data1.error_message!=null)
                                respstr += "{\"text\":\"" + "Sugarmate.io error: " + data1.error_message + "\",";
                            else
                                respstr += "{\"text\":\"" + "Sugarmate.io error\",";
                            respstr += "\"icon\":\"i2493";
                            respstr += "\",\"index\":0}";
                        } 
                        else
                        {
                            long sensortime = data1.x;

                            long sensordiff = epoch - sensortime;
                            string direction = data1.trend_words;

                            string iconstr;

                            bool redicon = false;
                            if (units == "mmol/L")
                            {
                                redicon = ((data1.value / 18f) <= sgvlow) || ((data1.value / 18f) >= sgvhigh);
                            } else {
                                redicon = (data1.value <= sgvlow) || (data1.value >= sgvhigh);
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
                                respstr += (data1.value / 18f).ToString("0.0;-0.0;0");
                                respstr += (((float)data1.delta) / 18f).ToString("+0.0;-0.0;+0");
                            } else {
                                respstr += data1.value.ToString();
                                respstr += data1.delta.ToString("+0;-0;+0");
                            }
                            respstr += "\",\"icon\":\"" + iconstr + "\",\"index\":0}";

                            // SENSOR TIME AGO
                            if (timeago == "true" || timeago == "1")
                            {
                                respstr += ",{\"text\":\"" + (sensordiff / 60.0).ToString("F0") + " min" + "\",\"icon\":\"";
                                respstr += sensordiff > 330 ? "i30926" : "i30918";
                                respstr += "\",\"index\":1}";
                            }
                        }
                    }
                } else
                {
                    respstr += "{\"text\":\"" + "Error " + ((int)dsStatus).ToString() + ": " + dsStatus.ToString() + "\",";
                    respstr += "\"icon\":\"i2493";
                    respstr += "\",\"index\":0}";
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