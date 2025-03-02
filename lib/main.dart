import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String accessToken = '';
void main() async {
  // 调用API获取数据
  var apiResponse = await fetchApiData();

  // 解析JSON数据
  var jsonData = jsonDecode(apiResponse.body);
  accessToken = jsonData['access_token'];

  // 打印JSON数据
  print(accessToken);
  runApp(const MyApp());
}

Future<http.Response> fetchApiData() async {
  var clientId = 'DCseX24YCnRjz9mqitbKCrfI';
  var clientSecret = 'Vzi4n41uXhoaJ2TmECnELttbBPlVSJjR';
  var url = Uri.parse('https://aip.baidubce.com/oauth/2.0/token?client_id=$clientId&client_secret=$clientSecret&grant_type=client_credentials');
  var response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    return response;
  } else {
    throw Exception('Failed to load API data');
  }
}

Future<Map<String, dynamic>> uploadImage(File imageFile) async {
  // 读取图像文件并将其转换为Base64编码的字符串
  List<int> imageBytes = await imageFile.readAsBytes();
  String base64Image = base64Encode(imageBytes);

  // 构建API请求URL
  String url = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/image-understanding/request?access_token=$accessToken';

  // 构建请求体
  Map<String, dynamic> payload = {
    "image": base64Image,
    "question": "识别图中食物或菜品，每种以格式{name: “”, unit:””, quantity: “”,Calorie: “”}输出，放在数组中"
  };

  // 发送POST请求
  var response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(payload),
  );

  if (response.statusCode == 200) {
    // 解析JSON响应
    Map<String, dynamic> jsonResponse = jsonDecode(response.body);
    return jsonResponse;
  } else {
    throw Exception('Failed to upload image');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拍照查卡路里',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '拍照查卡路里'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false; // 用于控制等待效果的显示
  File? _imageFile; // 用于存储选择的图片文件
  Map<String, dynamic> calData = {'result': {'description': "[\n    {\n        \"name\": \"\",\n        \"unit\": \"\",\n        \"quantity\": \"\",\n        \"Calorie\": \"\"\n    }\n]"}}; // 用于存储API的返回结果

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      try {
        Map<String, dynamic> _apiResult = await uploadImage(_imageFile!);
        var taskId = _apiResult['result']['task_id'];
        await pollApi(taskId);
        print(_apiResult);

        setState(() {}); // 更新UI以显示API结果
      } catch (e) {
        print('Error uploading image: $e');
      }
    }
  }

  Future<void> pollApi(String taskId) async {
    setState(() {
      _isLoading = true; // 显示等待效果
    });

    while (true) {
      calData = await fetchApiResult(taskId);
      print(calData);
      if (calData['result']['ret_msg'] == 'success') {
        setState(() {
          _isLoading = false; // 隐藏等待效果
        });
        break;
      }
      await Future.delayed(Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_imageFile != null)
                Card(
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover, // 使图片尽量沾满屏幕宽度
                  ),
                ),
              if (_isLoading)
                CircularProgressIndicator(), // 显示等待效果
              if (_imageFile != null && calData['result']['description'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: buildTable(jsonDecode(calData['result']['description'])),
                  ),
                ),
              if (calData['result']['task_id'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Task ID: ${calData['result']['task_id']}'),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => _pickImage(ImageSource.gallery),
            tooltip: '选择照片',
            child: const Icon(Icons.photo),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _pickImage(ImageSource.camera),
            tooltip: '拍照',
            child: const Icon(Icons.camera),
          ),
        ],
      ),
    );
  }

  Widget buildTable(List<dynamic> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('名称')),
          DataColumn(label: Text('单位')),
          DataColumn(label: Text('数量')),
          DataColumn(label: Text('卡路里')),
        ],
        rows: data.map((item) {
          return DataRow(cells: [
            DataCell(Text(item['name'])),
            DataCell(Text(item['unit'])),
            DataCell(Text(item['quantity'])),
            DataCell(Text(item['Calorie'])),
          ]);
        }).toList(),
      ),
    );
    }

  Future<Map<String, dynamic>> fetchApiResult(String taskId) async {
    String url = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/image-understanding/get-result?access_token=$accessToken';

    // 构建请求体
    Map<String, dynamic> payload = {
      "task_id": taskId,
    };

    // 发送POST请求
    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      // 解析JSON响应
      Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      
      // 检查并替换name字段为空字符串的情况
      if (jsonResponse['result']['description'] != null) {
        List<dynamic> data = jsonDecode(jsonResponse['result']['description'].replaceAll('```json', '').replaceAll('```', '').split(']')[0] + ']');
        for (var item in data) {
          if (item['name'] == '') {
            item['name'] = '未知';
          }
        }
        jsonResponse['result']['description'] = jsonEncode(data);
      }
      
      return jsonResponse;
    } else {
      throw Exception('Failed to fetch API result');
    }
  }
}
