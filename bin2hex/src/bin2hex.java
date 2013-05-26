import java.io.File;
import java.io.FileInputStream;
import java.io.PrintWriter;

public class bin2hex {
	private static int checksum = 0;

	private static byte[] readBinaryFile(String filename) throws Exception {
		File file = new File(filename);
		int size = (int) file.length();
		byte[] data = new byte[size];
		FileInputStream in = new FileInputStream(file);
		in.read(data);
		in.close();
		return data;
	}

	private static String hexByte(int b) {
		checksum += b;
		String result = Integer.toHexString(b & 0xff);
		if (result.length() < 2) {
			result = "0" + result;
		}
		return result;
	}

	private static void saveIntelHex(String filename, byte[] memory) throws Exception {
		int start = 0;
		int end = memory.length;
		PrintWriter out = new PrintWriter(new File(filename));

		// Intel Hex format:
		// : byte-count, address (16 bit), record type (00=data, 01=eof), data, checksum (2's complement of sum of data)
		
		// content
		int size = end - start;
		int blocks = (size + 31) / 32;
		for (int block = 0; block < blocks; block++) {
			// calculate current memory region, 32 bytes max. per line
			int currentStart = block * 32 + start;
			int currentEnd = currentStart + 32;
			if (currentEnd > end) {
				currentEnd = end;
			}
			int currentSize = currentEnd - currentStart;
			checksum = 0;

			// create one line of data
			String line = ":" + hexByte(currentSize) + hexByte((currentStart >> 8) & 0xff) + hexByte(currentStart & 0xff) + "00";
			for (int i = currentStart; i < currentEnd; i++) {
				line += hexByte(memory[i]);
			}

			// add checksum and write line
			line += hexByte((checksum ^ 0xff) + 1);
			out.println(line);
		}
		
		// eof
		out.println(":00000001FF");
		out.close();
	}

	public static void main(String args[]) throws Exception {
		if (args.length != 2) {
			System.out.println("usage: java bin2hex input.bin output.hex");
			return;
		}
		String inputFilename = args[0];
		String outputFilename = args[1];
		byte[] data = readBinaryFile(inputFilename);
		saveIntelHex(outputFilename, data);
	}
}
