#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stockfish.podspec' to validate before publishing.
#
#
require 'yaml'

pubspec = YAML.load(File.read(File.join(__dir__, '../pubspec.yaml')))

Pod::Spec.new do |s|
  s.name             = pubspec['name']
  s.version          = pubspec['version']
  s.summary          = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE', :type => 'MIT' }
  s.author           = 'Arjan Aswal'
  s.source = { :git => pubspec['repository'], :tag => s.version.to_s }
  s.source_files = 'Classes/**/*', 'FlutterStockfish/*', 'Stockfish/src/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.exclude_files = 'Stockfish/src/incbin/UNLICENCE'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.ios.deployment_target  = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # Additional compiler configuration required for Stockfish
  s.library = 'c++'
  s.script_phase = [
    {
      :execution_position => :before_compile,
      :name => 'Download nnue',
      :script => "cd \"${PODS_TARGET_SRCROOT}/Stockfish/src\" && [ -e 'nn-c288c895ea92.nnue' ] || curl --location --remote-name 'https://tests.stockfishchess.org/api/nn/nn-c288c895ea92.nnue'"
    },
    {
      :execution_position => :before_compile,
      :name => 'Download small nnue',
      :script => "cd \"${PODS_TARGET_SRCROOT}/Stockfish/src\" && [ -e 'nn-37f18f62d772.nnue' ] || curl --location --remote-name 'https://tests.stockfishchess.org/api/nn/nn-37f18f62d772.nnue'"
    },
    {
      :execution_position => :before_compile,
      :name => 'Copy nnue next to network.cpp for incbin',
      # incbin's `.incbin` assembler directive doesn't reliably honor the -I
      # search path under Xcode's build system, but it does resolve paths
      # relative to the directory of the .cpp being compiled (nnue/). Copy
      # both embedded network files there so the plain filename in
      # evaluate.h resolves regardless of which lookup clang uses.
      :script => "cp \"${PODS_TARGET_SRCROOT}/Stockfish/src/nn-c288c895ea92.nnue\" \"${PODS_TARGET_SRCROOT}/Stockfish/src/nnue/nn-c288c895ea92.nnue\" && cp \"${PODS_TARGET_SRCROOT}/Stockfish/src/nn-37f18f62d772.nnue\" \"${PODS_TARGET_SRCROOT}/Stockfish/src/nnue/nn-37f18f62d772.nnue\""
    },
  ]
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS[config=Debug]' => '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -I"${PODS_TARGET_SRCROOT}/Stockfish/src"',
    'OTHER_LDFLAGS[config=Debug]' => '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT',
    'OTHER_CPLUSPLUSFLAGS[config=Release]' => '$(inherited) -fno-exceptions -std=c++17 -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -flto=full -I"${PODS_TARGET_SRCROOT}/Stockfish/src"',
    'OTHER_LDFLAGS[config=Release]' => '$(inherited) -fno-exceptions -std=c++17 -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -flto=full'
  }
end
